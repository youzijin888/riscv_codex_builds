#!/usr/bin/env bash
set -euo pipefail

if [ $# -lt 2 ]; then
  echo "usage: $0 /path/to/codex <codex-version> [rust-target]" >&2
  exit 2
fi

BINARY_PATH="$1"
CODEX_VERSION="${2#v}"
RUST_TARGET="${3:-${RUST_TARGET:-riscv64gc-unknown-linux-gnu}}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
TAG="codex-v${CODEX_VERSION}-${RUST_TARGET}"
RELEASE_DIR="${RELEASE_DIR:-$ROOT_DIR/work/releases/$TAG}"
ARCHIVE="codex-${CODEX_VERSION}-${RUST_TARGET}.tar.gz"
STRIP_BIN="${STRIP_BIN:-strip}"
CODEX_SOURCE_DIR="${CODEX_SOURCE_DIR:-$ROOT_DIR/work/codex-$CODEX_VERSION}"

if [ ! -f "$BINARY_PATH" ]; then
  echo "binary not found: $BINARY_PATH" >&2
  exit 1
fi

mkdir -p "$RELEASE_DIR"
temp_dir="$(mktemp -d)"
trap 'rm -rf "$temp_dir"' EXIT

install -m 0755 "$BINARY_PATH" "$temp_dir/codex"

if command -v "$STRIP_BIN" >/dev/null 2>&1; then
  "$STRIP_BIN" --strip-debug "$temp_dir/codex"
else
  echo "warning: strip tool not found; packaging unstripped binary" >&2
fi

for legal_file in LICENSE NOTICE; do
  if [ -f "$CODEX_SOURCE_DIR/$legal_file" ]; then
    install -m 0644 "$CODEX_SOURCE_DIR/$legal_file" "$temp_dir/$legal_file"
  fi
done

"$temp_dir/codex" --version
tar --owner=0 --group=0 --numeric-owner -C "$temp_dir" \
  -czf "$RELEASE_DIR/$ARCHIVE" .

(
  cd "$RELEASE_DIR"
  sha256sum "$ARCHIVE" > SHA256SUMS
)

cat <<EOF
release_tag=$TAG
release_archive=$RELEASE_DIR/$ARCHIVE
release_checksums=$RELEASE_DIR/SHA256SUMS
EOF
