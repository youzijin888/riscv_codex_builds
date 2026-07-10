#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

WORK_DIR="${WORK_DIR:-$ROOT_DIR/work}"
ARTIFACT_ROOT="${ARTIFACT_ROOT:-$WORK_DIR/artifacts}"
RUST_TARGET="${RUST_TARGET:-riscv64gc-unknown-linux-gnu}"

mkdir -p "$WORK_DIR" "$ARTIFACT_ROOT"

metadata="$("$SCRIPT_DIR/resolve-latest.sh")"
eval "$metadata"

echo "$metadata"

export WORK_DIR
export RUST_TARGET
export RUST_TOOLCHAIN="$rust_toolchain"

local_v8_dir="$ROOT_DIR/v8-artifacts/rusty-v8-v${v8_version}-${RUST_TARGET}"
local_v8_archive="$local_v8_dir/librusty_v8_release_${RUST_TARGET}.a.gz"
local_v8_binding="$local_v8_dir/src_binding_release_${RUST_TARGET}.rs"

if [ -f "$local_v8_archive" ] && [ -f "$local_v8_binding" ]; then
  if [ -f "$local_v8_dir/SHA256SUMS" ]; then
    (cd "$local_v8_dir" && sha256sum -c SHA256SUMS)
  fi
  rusty_v8_archive="$local_v8_archive"
  rusty_v8_src_binding="$local_v8_binding"
  echo "rusty_v8_archive=$rusty_v8_archive"
  echo "rusty_v8_src_binding=$rusty_v8_src_binding"
  echo "rusty_v8_artifact_dir=$local_v8_dir"
else
  rusty_output="$(
    ARTIFACT_DIR="$ARTIFACT_ROOT/rusty-v8-v${v8_version}-${RUST_TARGET}" \
      "$SCRIPT_DIR/build-rusty-v8.sh" "$v8_version"
  )"

  echo "$rusty_output"
  eval "$rusty_output"
fi

codex_output="$(
  ARTIFACT_DIR="$ARTIFACT_ROOT/codex-${codex_version}-${RUST_TARGET}" \
    "$SCRIPT_DIR/build-codex.sh" "$codex_checkout" "$rusty_v8_archive" "$rusty_v8_src_binding"
)"

echo "$codex_output"
