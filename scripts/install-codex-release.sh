#!/usr/bin/env bash
set -euo pipefail

DEFAULT_CODEX_VERSION="0.144.1"
CODEX_VERSION="${1:-${CODEX_VERSION:-$DEFAULT_CODEX_VERSION}}"
CODEX_VERSION="${CODEX_VERSION#v}"
RUST_TARGET="${2:-${RUST_TARGET:-riscv64gc-unknown-linux-gnu}}"
REPO="${REPO:-youzijin888/riscv_codex_builds}"
INSTALL_PATH="${INSTALL_PATH:-$HOME/.local/bin/codex}"

TAG="codex-v${CODEX_VERSION}-${RUST_TARGET}"
ARCHIVE="codex-${CODEX_VERSION}-${RUST_TARGET}.tar.gz"
BASE_URL="${BASE_URL:-https://github.com/$REPO/releases/download/$TAG}"

temp_dir="$(mktemp -d)"
trap 'rm -rf "$temp_dir"' EXIT

curl -fL --retry 5 --retry-delay 5 -o "$temp_dir/$ARCHIVE" \
  "$BASE_URL/$ARCHIVE"
curl -fL --retry 5 --retry-delay 5 -o "$temp_dir/SHA256SUMS" \
  "$BASE_URL/SHA256SUMS"

(
  cd "$temp_dir"
  sha256sum -c SHA256SUMS
  tar -xzf "$ARCHIVE"
)

install_dir="$(dirname "$INSTALL_PATH")"
mkdir -p "$install_dir"
install -m 0755 "$temp_dir/codex" "${INSTALL_PATH}.new"
mv -f "${INSTALL_PATH}.new" "$INSTALL_PATH"

"$INSTALL_PATH" --version
