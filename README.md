# Codex RISC-V Maintainer

Scripts for building the latest stable Rust Codex CLI for
`riscv64gc-unknown-linux-gnu`.

The workflow is:

1. Resolve the latest stable `openai/codex` Rust tag.
2. Read the matching `v8` crate version from `codex-rs/Cargo.toml`.
3. Build that exact `denoland/rusty_v8` version from source for RISC-V.
4. Patch Codex for RISC-V OpenSSL and seccomp support.
5. Build `codex-cli`.

## Host requirements

Install the usual Rust and cross-build tools first:

```bash
sudo apt install build-essential git curl python3 pkg-config \
  gcc-riscv64-linux-gnu g++-riscv64-linux-gnu \
  clang libclang-19-dev ninja-build gn libglib2.0-dev
```

Install the Rust toolchain used by Codex. The scripts can read this from the
Codex checkout, but Rustup must be present:

```bash
rustup toolchain install 1.95.0
rustup target add riscv64gc-unknown-linux-gnu --toolchain 1.95.0
```

## Build latest stable Codex

```bash
cd codex-riscv-maintainer
scripts/build-latest.sh
```

By default outputs go under `./work/artifacts`.

Useful overrides:

```bash
WORK_DIR=/data/codex-riscv-work \
ARTIFACT_DIR=/data/codex-riscv-artifacts \
RUST_TARGET=riscv64gc-unknown-linux-gnu \
scripts/build-latest.sh
```

## Build only rusty_v8

For the current latest stable Codex at the time this scaffold was verified,
`rust-v0.143.0` uses `v8 = "=149.2.0"`.

```bash
scripts/build-rusty-v8.sh 149.2.0
```

For long native RISC-V builds, the monitored wrapper is usually safer. It prints
progress every 30 seconds and can automatically restart with fewer jobs if
memory gets too tight:

```bash
scripts/build-rusty-v8-monitored.sh 149.2.0 4
```

Useful monitor overrides:

```bash
INTERVAL=60 MIN_AVAILABLE_MIB=2048 MAX_SWAP_MIB=512 \
scripts/build-rusty-v8-monitored.sh 149.2.0 4
```

The produced files are:

```text
librusty_v8_release_riscv64gc-unknown-linux-gnu.a.gz
src_binding_release_riscv64gc-unknown-linux-gnu.rs
```

These are the two files Codex consumes through:

```bash
export RUSTY_V8_ARCHIVE=/path/to/librusty_v8_release_riscv64gc-unknown-linux-gnu.a.gz
export RUSTY_V8_SRC_BINDING_PATH=/path/to/src_binding_release_riscv64gc-unknown-linux-gnu.rs
```

## Stable versus alpha

`scripts/build-latest.sh` intentionally follows stable `rust-vX.Y.Z` tags and
ignores `alpha` tags. If you want to track alpha/main later, keep it as a
separate workflow because the Codex patch and `rusty_v8` build assumptions can
change more often.

## Storage and jobs

The C++ compile phase is mostly CPU and RAM bound, but an SSD still helps with
clone/submodule checkout, generated files, incremental rebuild scans, linking,
archiving, and gzip output. Avoid slow SD cards, USB flash drives, network
filesystems, or heavy swap during the V8 build.

On 16 GiB RISC-V machines, start with 4 jobs. On 8 GiB machines, start with 3
jobs only if swap stays near zero. If available memory drops below about 2 GiB
or swap starts growing quickly, restart with fewer jobs; existing object files
are reused.
