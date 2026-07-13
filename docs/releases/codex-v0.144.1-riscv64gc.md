# Codex CLI 0.144.1 for RISC-V

Prebuilt Codex CLI `0.144.1` for `riscv64gc-unknown-linux-gnu`.

## Compatibility

- 64-bit RISC-V Linux
- glibc with the LP64D ABI
- Runtime libraries: `libstdc++.so.6` and `liblzma.so.5`
- Built with `rusty_v8 149.2.0`

## Install

From a clone of this repository:

```bash
scripts/install-codex-release.sh 0.144.1
```

See [Install and update](../install-update.md) for runtime dependencies,
custom installation paths, updates, rollback, and troubleshooting.

## Release assets

```text
codex-0.144.1-riscv64gc-unknown-linux-gnu.tar.gz
SHA256SUMS
```

SHA256:

```text
d1f73418be869b79d77fc1e7f7ffdfd9081336ecf6675e44d9a35416001d367e  codex-0.144.1-riscv64gc-unknown-linux-gnu.tar.gz
```

The archive contains the `codex` executable and the upstream `LICENSE` and
`NOTICE` files.

## Build notes

The final link used `/usr/bin/g++` with an explicit `-lstdc++`. On the 16 GiB
build host, the GNU linker peaked near 8.9 GiB RSS and swap usage peaked near
4.2 GiB. Detailed notes are in
[Codex 0.144.1 RISC-V build notes](../codex-0.144.1-riscv64gc-build-notes.md).
