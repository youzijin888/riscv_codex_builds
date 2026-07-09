#!/usr/bin/env bash
set -euo pipefail

if [ $# -lt 3 ]; then
  echo "usage: $0 /path/to/codex-checkout /path/to/librusty_v8.a.gz /path/to/src_binding.rs" >&2
  exit 2
fi

CODEX_DIR="$1"
RUSTY_V8_ARCHIVE_PATH="$2"
RUSTY_V8_BINDING_PATH="$3"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

RUST_TARGET="${RUST_TARGET:-riscv64gc-unknown-linux-gnu}"
RUST_TOOLCHAIN="${RUST_TOOLCHAIN:-1.95.0}"
WORK_DIR="${WORK_DIR:-$ROOT_DIR/work}"
ARTIFACT_DIR="${ARTIFACT_DIR:-$WORK_DIR/artifacts/codex-${RUST_TARGET}}"

if [ -f "$HOME/.cargo/env" ]; then
  # shellcheck disable=SC1091
  . "$HOME/.cargo/env"
fi

mkdir -p "$ARTIFACT_DIR"

"$SCRIPT_DIR/patch-codex-riscv.sh" "$CODEX_DIR" >&2

export RUSTY_V8_ARCHIVE="$RUSTY_V8_ARCHIVE_PATH"
export RUSTY_V8_SRC_BINDING_PATH="$RUSTY_V8_BINDING_PATH"
export CARGO_PROFILE_RELEASE_LTO="${CARGO_PROFILE_RELEASE_LTO:-false}"
export CARGO_PROFILE_RELEASE_CODEGEN_UNITS="${CARGO_PROFILE_RELEASE_CODEGEN_UNITS:-16}"

host_triple="$(rustc "+${RUST_TOOLCHAIN}" -Vv | sed -n 's/^host: //p')"
if [ "$host_triple" != "$RUST_TARGET" ]; then
  export CARGO_TARGET_RISCV64GC_UNKNOWN_LINUX_GNU_LINKER="${CARGO_TARGET_RISCV64GC_UNKNOWN_LINUX_GNU_LINKER:-/usr/bin/riscv64-linux-gnu-g++}"
  export CC_riscv64gc_unknown_linux_gnu="${CC_riscv64gc_unknown_linux_gnu:-/usr/bin/riscv64-linux-gnu-gcc}"
  export CXX_riscv64gc_unknown_linux_gnu="${CXX_riscv64gc_unknown_linux_gnu:-/usr/bin/riscv64-linux-gnu-g++}"
fi

(
  cd "$CODEX_DIR/codex-rs"
  cargo "+${RUST_TOOLCHAIN}" build --release -p codex-cli --bin codex --target "$RUST_TARGET"
)

version="$(sed -n 's/^version = "\([^"]*\)"/\1/p' "$CODEX_DIR/codex-rs/Cargo.toml" | head -1)"
binary="$CODEX_DIR/codex-rs/target/$RUST_TARGET/release/codex"
out="$ARTIFACT_DIR/codex-${version:-unknown}-${RUST_TARGET}"

cp "$binary" "$out"
sha256sum "$out" > "$ARTIFACT_DIR/SHA256SUMS"

cat <<EOF
codex_binary=$out
codex_artifact_dir=$ARTIFACT_DIR
EOF
