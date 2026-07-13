# Install and Update Codex on RISC-V

This repository publishes prebuilt Codex CLI releases for
`riscv64gc-unknown-linux-gnu`. The binaries target 64-bit RISC-V Linux with
glibc and the LP64D ABI.

## Runtime requirements

The `0.144.1` binary dynamically links the following system libraries:

```text
libc.so.6
libgcc_s.so.1
libm.so.6
liblzma.so.5
libstdc++.so.6
ld-linux-riscv64-lp64d.so.1
```

On Ubuntu or Debian RISC-V systems, install the download and runtime packages
with:

```bash
sudo apt-get update
sudo apt-get install ca-certificates curl liblzma5 libstdc++6
```

The release is not a musl binary and will not run on a system without the
glibc RISC-V LP64D loader.

## Install from this repository

Run the installer from a clone:

```bash
scripts/install-codex-release.sh 0.144.1
```

It performs these operations:

1. Downloads the release archive and `SHA256SUMS`.
2. Verifies the archive before extraction.
3. Installs to `~/.local/bin/.codex.new`.
4. Atomically replaces `~/.local/bin/codex` with `mv -f`.
5. Runs `codex --version`.

Make sure `~/.local/bin` is in `PATH`:

```bash
export PATH="$HOME/.local/bin:$PATH"
```

## Install without cloning

Download the installer from GitHub and run it:

```bash
curl -fsSLO \
  https://raw.githubusercontent.com/youzijin888/riscv_codex_builds/main/scripts/install-codex-release.sh
chmod +x install-codex-release.sh
./install-codex-release.sh 0.144.1
```

Remove the downloaded installer afterward if it is no longer needed.

## Update

Run the same installer with the new release version:

```bash
scripts/install-codex-release.sh NEW_VERSION
```

The update is an atomic file replacement. A Codex process that is already
running keeps using the previous executable until it exits. Restart Codex to
use the newly installed version.

## Custom install path

Set `INSTALL_PATH` when `~/.local/bin/codex` is not appropriate:

```bash
INSTALL_PATH=/opt/codex/bin/codex \
  scripts/install-codex-release.sh 0.144.1
```

The destination directory must be writable. Use `sudo` only when installing
to a system-owned directory.

## Verify

Check the installed version and architecture:

```bash
codex --version
file "$(command -v codex)"
ldd "$(command -v codex)"
```

Expected version output for this release:

```text
codex-cli 0.144.1
```

## Roll back

Run the installer with an older published version:

```bash
scripts/install-codex-release.sh OLD_VERSION
```

Because each release is versioned and checksum-verified, rollback uses the
same installation path as an update.

## Troubleshooting

`cannot execute: required file not found` usually means the system does not
provide `/lib/ld-linux-riscv64-lp64d.so.1`, or the host is not compatible with
the release ABI.

Errors mentioning `libstdc++.so.6` or `liblzma.so.5` mean the matching runtime
package is missing. Install `libstdc++6` or `liblzma5` and retry.

A warning about being unable to create PATH aliases can occur in a restricted
or read-only sandbox. If `codex --version` succeeds and `~/.local/bin` is in
`PATH`, the installed executable is usable.
