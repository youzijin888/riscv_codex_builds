#!/usr/bin/env bash
set -euo pipefail

CODEX_REPO="${CODEX_REPO:-https://github.com/openai/codex.git}"
WORK_DIR="${WORK_DIR:-$(pwd)/work}"

mkdir -p "$WORK_DIR"

latest_version="$(
  git ls-remote --tags "$CODEX_REPO" 'refs/tags/rust-v*' \
    | sed -n 's#.*refs/tags/rust-v\([0-9][0-9.]*\)$#\1#p' \
    | sort -V \
    | tail -1
)"

if [ -z "$latest_version" ]; then
  echo "failed to resolve latest stable Codex rust tag" >&2
  exit 1
fi

codex_tag="rust-v${latest_version}"
checkout="$WORK_DIR/codex-${latest_version}"

if [ ! -d "$checkout/.git" ]; then
  rm -rf "$checkout"
  git clone --depth 1 --branch "$codex_tag" "$CODEX_REPO" "$checkout"
fi

cargo_toml="$checkout/codex-rs/Cargo.toml"
toolchain_toml="$checkout/codex-rs/rust-toolchain.toml"

v8_version="$(sed -n 's/^v8 = "=\([0-9][0-9.]*\)"/\1/p' "$cargo_toml" | head -1)"
rust_toolchain="$(sed -n 's/^channel = "\([^"]*\)"/\1/p' "$toolchain_toml" | head -1)"

if [ -z "$v8_version" ]; then
  echo "failed to read v8 version from $cargo_toml" >&2
  exit 1
fi

if [ -z "$rust_toolchain" ]; then
  echo "failed to read Rust toolchain from $toolchain_toml" >&2
  exit 1
fi

cat <<EOF
codex_version=$latest_version
codex_tag=$codex_tag
codex_checkout=$checkout
v8_version=$v8_version
rust_toolchain=$rust_toolchain
EOF

