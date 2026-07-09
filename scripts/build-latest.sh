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

rusty_output="$(
  ARTIFACT_DIR="$ARTIFACT_ROOT/rusty-v8-v${v8_version}-${RUST_TARGET}" \
    "$SCRIPT_DIR/build-rusty-v8.sh" "$v8_version"
)"

echo "$rusty_output"
eval "$rusty_output"

codex_output="$(
  ARTIFACT_DIR="$ARTIFACT_ROOT/codex-${codex_version}-${RUST_TARGET}" \
    "$SCRIPT_DIR/build-codex.sh" "$codex_checkout" "$rusty_v8_archive" "$rusty_v8_src_binding"
)"

echo "$codex_output"

