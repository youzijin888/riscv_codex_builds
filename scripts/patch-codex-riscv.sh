#!/usr/bin/env bash
set -euo pipefail

codex_dir="${1:-}"

if [ -z "$codex_dir" ]; then
  echo "usage: $0 /path/to/codex-checkout" >&2
  exit 2
fi

core_toml="$codex_dir/codex-rs/core/Cargo.toml"
landlock_rs="$codex_dir/codex-rs/linux-sandbox/src/landlock.rs"

if [ ! -f "$core_toml" ] || [ ! -f "$landlock_rs" ]; then
  echo "not an openai/codex checkout: $codex_dir" >&2
  exit 2
fi

if ! grep -q 'target.riscv64gc-unknown-linux-gnu.dependencies' "$core_toml"; then
  tmp="${core_toml}.tmp"
  awk '
    { print }
    /^\[target\.aarch64-unknown-linux-musl\.dependencies\]$/ { in_aarch64 = 1; next }
    in_aarch64 && /^openssl-sys =/ {
      print ""
      print "[target.riscv64gc-unknown-linux-gnu.dependencies]"
      print "openssl-sys = { workspace = true, features = [\"vendored\"] }"
      in_aarch64 = 0
    }
  ' "$core_toml" > "$tmp"
  mv "$tmp" "$core_toml"
fi

if ! grep -q 'target_arch = "riscv64"' "$landlock_rs"; then
  perl -0pi -e 's/(} else if cfg!\(target_arch = "aarch64"\) \{\n\s+TargetArch::aarch64\n\s+)(} else \{)/$1} else if cfg!(target_arch = "riscv64") {\n            TargetArch::riscv64\n        $2/' "$landlock_rs"
fi

grep -q 'target.riscv64gc-unknown-linux-gnu.dependencies' "$core_toml"
grep -q 'target_arch = "riscv64"' "$landlock_rs"

echo "patched Codex for riscv64gc"

