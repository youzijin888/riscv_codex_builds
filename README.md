# Codex RISC-V Maintainer

[![License](https://img.shields.io/github/license/youzijin888/riscv-codex-builds)](LICENSE)
[![Latest release](https://img.shields.io/github/v/release/youzijin888/riscv-codex-builds?display_name=tag)](https://github.com/youzijin888/riscv-codex-builds/releases)

Scripts for building the latest stable Rust Codex CLI for
`riscv64gc-unknown-linux-gnu`.

This repository publishes reproducible scripts, build notes, and
checksum-verified RISC-V release artifacts. It is intended for maintainers and
advanced users who want to run Codex CLI on 64-bit RISC-V Linux systems.

The workflow is:

1. Resolve the latest stable `openai/codex` Rust tag.
2. Read the matching `v8` crate version from `codex-rs/Cargo.toml`.
3. Build that exact `denoland/rusty_v8` version from source for RISC-V.
4. Patch Codex for RISC-V OpenSSL and seccomp support.
5. Build `codex-cli`.

## Install the prebuilt Codex CLI

The current verified release is Codex CLI `0.144.1` for
`riscv64gc-unknown-linux-gnu` (glibc, LP64D ABI).

From a clone of this repository:

```bash
scripts/install-codex-release.sh 0.144.1
```

The installer downloads the GitHub Release archive, verifies `SHA256SUMS`,
and atomically replaces `~/.local/bin/codex`. Running Codex processes continue
using their existing executable; new processes use the updated version.

See [Install and update](docs/install-update.md) for runtime requirements,
direct-download commands, custom install paths, updates, and rollback.

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
cd riscv-codex-builds
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

For the current stable Codex verified by this repository,
`rust-v0.144.1` uses `v8 = "=149.2.0"`.

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

## Package a Codex release

After a successful build, create a debug-stripped and compressed GitHub Release
asset with:

```bash
scripts/package-codex-release.sh \
  work/artifacts/codex-riscv64gc-unknown-linux-gnu/codex-0.144.1-riscv64gc-unknown-linux-gnu \
  0.144.1
```

The release files are written under:

```text
work/releases/codex-v0.144.1-riscv64gc-unknown-linux-gnu/
```

## Repository layout

```text
scripts/        Build, patch, package, download, and install helpers
docs/           Build notes, install/update docs, and release notes
v8-artifacts/   Metadata and small files for reusable rusty_v8 artifacts
```

Large `rusty_v8` static libraries are published through GitHub Release assets
instead of normal Git blobs.

## Contributing

RISC-V build reports, packaging fixes, and documentation improvements are
welcome. Start with [CONTRIBUTING.md](CONTRIBUTING.md), and include host
hardware, distro, memory, swap, Rust toolchain, and the exact Codex/rusty_v8
versions when reporting build behavior.

## Security

Release artifacts are published with `SHA256SUMS`; verify checksums before
installing. For private vulnerability reports, see [SECURITY.md](SECURITY.md).

## License

This repository is licensed under the [Apache License 2.0](LICENSE). Codex,
Rust, V8, rusty_v8, and other third-party components remain subject to their
own upstream licenses and notices. Packaged Codex release archives include the
upstream `LICENSE` and `NOTICE` files when available.
