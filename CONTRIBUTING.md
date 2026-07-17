# Contributing

Thanks for helping maintain Codex CLI builds for RISC-V.

## Useful contributions

- Build reports from real `riscv64gc-unknown-linux-gnu` hosts.
- Fixes for Codex, OpenSSL, seccomp, or `rusty_v8` RISC-V build issues.
- Improvements to release packaging and checksum verification.
- Documentation for memory, swap, linker, and toolchain behavior.

## Reporting build results

Please include:

- hardware or VM provider
- CPU, RAM, swap, and storage type
- Linux distribution and kernel version
- Rust toolchain version
- Codex tag and `rusty_v8` version
- full command used
- failing log excerpt, with private paths and tokens removed

## Pull requests

Keep changes focused. For script changes, run:

```bash
bash -n scripts/*.sh
```

If your change affects a release artifact, update the matching docs under
`docs/releases/` and include checksum information.

## Third-party code

This repository builds and packages third-party projects. Do not remove upstream
license or notice files from release archives.
