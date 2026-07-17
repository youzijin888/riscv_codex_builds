# Security Policy

## Supported scope

This repository publishes scripts and release artifacts for Codex CLI on
RISC-V Linux. Security reports should focus on:

- release archive integrity
- checksum verification
- installer behavior
- build scripts and patch scripts
- accidental exposure of credentials or private host paths

## Reporting a vulnerability

Please do not open a public issue for sensitive reports. Email
`youzijin8@gmail.com` with:

- affected release tag or commit
- reproduction steps
- expected impact
- suggested mitigation if available

## Artifact verification

Always verify `SHA256SUMS` before installing a release artifact. The installer
does this automatically for official release downloads.

## Third-party components

Codex, V8, Rust, and `rusty_v8` have their own upstream security policies and
licenses. Vulnerabilities in those projects should also be reported upstream.
