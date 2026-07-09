#!/usr/bin/env bash
set -euo pipefail

if [ $# -lt 1 ]; then
  echo "usage: $0 <v8-version>" >&2
  exit 2
fi

V8_VERSION="$1"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

RUSTY_V8_REPO="${RUSTY_V8_REPO:-https://github.com/denoland/rusty_v8.git}"
RUST_TARGET="${RUST_TARGET:-riscv64gc-unknown-linux-gnu}"
RUST_TOOLCHAIN="${RUST_TOOLCHAIN:-1.95.0}"
WORK_DIR="${WORK_DIR:-$ROOT_DIR/work}"
ARTIFACT_DIR="${ARTIFACT_DIR:-$WORK_DIR/artifacts/rusty-v8-v${V8_VERSION}-${RUST_TARGET}}"
LOCAL_TOOLS_DIR="${LOCAL_TOOLS_DIR:-$WORK_DIR/tools/root}"
BUILD_JOBS="${JOBS:-${CARGO_BUILD_JOBS:-${NUM_JOBS:-4}}}"

export CARGO_BUILD_JOBS="${CARGO_BUILD_JOBS:-$BUILD_JOBS}"
export NUM_JOBS="${NUM_JOBS:-$BUILD_JOBS}"

if [ -f "$HOME/.cargo/env" ]; then
  # shellcheck disable=SC1091
  . "$HOME/.cargo/env"
fi

if [ -x "$LOCAL_TOOLS_DIR/usr/bin/gn" ] && [ -x "$LOCAL_TOOLS_DIR/usr/bin/ninja" ]; then
  export PATH="$LOCAL_TOOLS_DIR/usr/bin:$LOCAL_TOOLS_DIR/usr/lib/llvm-19/bin:$PATH"
  export GN="${GN:-$LOCAL_TOOLS_DIR/usr/bin/gn}"
  export NINJA="${NINJA:-$LOCAL_TOOLS_DIR/usr/bin/ninja}"
fi

if [ -x "$LOCAL_TOOLS_DIR/usr/lib/llvm-19/bin/clang" ]; then
  export CLANG_BASE_PATH="${CLANG_BASE_PATH:-$LOCAL_TOOLS_DIR/usr/lib/llvm-19}"
fi

if [ -f "$LOCAL_TOOLS_DIR/usr/lib/llvm-19/lib/libclang.so" ]; then
  export LIBCLANG_PATH="${LIBCLANG_PATH:-$LOCAL_TOOLS_DIR/usr/lib/llvm-19/lib}"
  export LD_LIBRARY_PATH="$LOCAL_TOOLS_DIR/usr/lib/riscv64-linux-gnu${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
fi

mkdir -p "$WORK_DIR" "$ARTIFACT_DIR"

src="$WORK_DIR/rusty_v8-v${V8_VERSION}"
if [ ! -d "$src/.git" ]; then
  rm -rf "$src"
  git clone --depth 1 --branch "v${V8_VERSION}" "$RUSTY_V8_REPO" "$src"
fi

if [ ! -f "$src/v8/DEPS" ]; then
  git -C "$src" submodule update --init --recursive --depth 1
fi

rust_sysroot="$(rustc "+${RUST_TOOLCHAIN}" --print sysroot)"
export RUST_SYSROOT_ABSOLUTE="${RUST_SYSROOT_ABSOLUTE:-$rust_sysroot}"
rustc_short_version="$(rustc "+${RUST_TOOLCHAIN}" -V | awk '{print $2}')"
export RUSTC_VERSION="${RUSTC_VERSION:-$rustc_short_version}"
if [ -x "$WORK_DIR/tools/bindgen/bin/bindgen" ]; then
  export RUST_BINDGEN_ROOT="${RUST_BINDGEN_ROOT:-$WORK_DIR/tools/bindgen}"
fi

rust_toolchain_path="$src/third_party/rust-toolchain"
if [ ! -e "$rust_toolchain_path" ] && [ ! -L "$rust_toolchain_path" ]; then
  ln -s "$RUST_SYSROOT_ABSOLUTE" "$rust_toolchain_path"
fi

"$SCRIPT_DIR/patch-rusty-v8-riscv.sh" "$src" >&2

export V8_FROM_SOURCE="${V8_FROM_SOURCE:-1}"
export PRINT_GN_ARGS="${PRINT_GN_ARGS:-0}"
export LIBCLANG_PATH="${LIBCLANG_PATH:-/usr/lib/llvm-19/lib}"
export CARGO_TARGET_DIR="${CARGO_TARGET_DIR:-$src/target}"
export RUSTC_BOOTSTRAP="${RUSTC_BOOTSTRAP:-1}"
export GN_ARGS="${GN_ARGS:-use_custom_libcxx=false}"

host_triple="$(rustc "+${RUST_TOOLCHAIN}" -Vv | sed -n 's/^host: //p')"
if [ "$host_triple" != "$RUST_TARGET" ]; then
  export CARGO_TARGET_RISCV64GC_UNKNOWN_LINUX_GNU_LINKER="${CARGO_TARGET_RISCV64GC_UNKNOWN_LINUX_GNU_LINKER:-/usr/bin/riscv64-linux-gnu-g++}"
  export CC_riscv64gc_unknown_linux_gnu="${CC_riscv64gc_unknown_linux_gnu:-/usr/bin/riscv64-linux-gnu-gcc}"
  export CXX_riscv64gc_unknown_linux_gnu="${CXX_riscv64gc_unknown_linux_gnu:-/usr/bin/riscv64-linux-gnu-g++}"
fi

(
  cd "$src"
  cargo_args=(build --release --target "$RUST_TARGET")
  case "${CARGO_VERBOSE:-1}" in
    0) ;;
    1) cargo_args+=(--verbose) ;;
    *) cargo_args+=(-vv) ;;
  esac
  cargo "+${RUST_TOOLCHAIN}" "${cargo_args[@]}"
)

lib_path="$(find "$CARGO_TARGET_DIR/$RUST_TARGET/release/build" -path '*/out/gn_out/obj/librusty_v8.a' -print | head -1)"
binding_path="$(find "$CARGO_TARGET_DIR/$RUST_TARGET/release/build" -path '*/out/gn_out/src_binding.rs' -print | head -1)"

if [ -z "$lib_path" ]; then
  lib_path="$CARGO_TARGET_DIR/$RUST_TARGET/release/gn_out/obj/librusty_v8.a"
fi
if [ -z "$binding_path" ]; then
  binding_path="$CARGO_TARGET_DIR/$RUST_TARGET/release/gn_out/src_binding.rs"
fi

if [ ! -f "$lib_path" ] || [ ! -f "$binding_path" ]; then
  echo "failed to locate rusty_v8 build outputs under $CARGO_TARGET_DIR" >&2
  exit 1
fi

archive="$ARTIFACT_DIR/librusty_v8_release_${RUST_TARGET}.a.gz"
binding="$ARTIFACT_DIR/src_binding_release_${RUST_TARGET}.rs"

gzip -c "$lib_path" > "$archive"
cp "$binding_path" "$binding"

sha256sum "$archive" "$binding" > "$ARTIFACT_DIR/SHA256SUMS"

cat <<EOF
rusty_v8_archive=$archive
rusty_v8_src_binding=$binding
rusty_v8_artifact_dir=$ARTIFACT_DIR
EOF
