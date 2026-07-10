#!/usr/bin/env bash
set -euo pipefail

if [ $# -lt 1 ]; then
  echo "usage: $0 <v8-version> [rust-target]" >&2
  echo "example: $0 149.2.0 riscv64gc-unknown-linux-gnu" >&2
  exit 2
fi

V8_VERSION="$1"
RUST_TARGET="${2:-${RUST_TARGET:-riscv64gc-unknown-linux-gnu}}"
REPO="${REPO:-youzijin888/riscv_codex_builds}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

TAG="rusty-v8-v${V8_VERSION}-${RUST_TARGET}"
DEST_DIR="${DEST_DIR:-$ROOT_DIR/v8-artifacts/$TAG}"
BASE_URL="https://github.com/$REPO/releases/download/$TAG"

mkdir -p "$DEST_DIR"

download() {
  local name="$1"
  curl -fL --retry 5 --retry-delay 5 -o "$DEST_DIR/$name" "$BASE_URL/$name"
}

download "librusty_v8_release_${RUST_TARGET}.a.gz"
download "src_binding_release_${RUST_TARGET}.rs"
download "SHA256SUMS"

(
  cd "$DEST_DIR"
  sha256sum -c SHA256SUMS
)

cat <<EOF
rusty_v8_archive=$DEST_DIR/librusty_v8_release_${RUST_TARGET}.a.gz
rusty_v8_src_binding=$DEST_DIR/src_binding_release_${RUST_TARGET}.rs
rusty_v8_artifact_dir=$DEST_DIR
EOF
