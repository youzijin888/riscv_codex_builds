# Codex 0.144.1 RISC-V Build Notes

These notes record the native `riscv64gc-unknown-linux-gnu` build and install
of Codex CLI `0.144.1` on the Muse Pi Pro board.

## Result

The built artifact is:

```text
work/artifacts/codex-riscv64gc-unknown-linux-gnu/codex-0.144.1-riscv64gc-unknown-linux-gnu
```

The installed command is:

```text
/home/xmut1613/.local/bin/codex
```

Verification:

```text
codex-cli 0.144.1
SHA256 be332cd35b77aeeb3a8f4dd0917158ac1a88ebc0c798607ef7db3f9a7507ac8f
```

## Install

Use an atomic replacement instead of writing directly over the running
executable:

```bash
install -m 0755 \
  work/artifacts/codex-riscv64gc-unknown-linux-gnu/codex-0.144.1-riscv64gc-unknown-linux-gnu \
  /home/xmut1613/.local/bin/.codex.new
mv -f /home/xmut1613/.local/bin/.codex.new /home/xmut1613/.local/bin/codex
/home/xmut1613/.local/bin/codex --version
```

The `mv -f` step replaces the directory entry. Existing running Codex
processes keep using their old inode, while new launches use the new binary.

## Known Issues

### Swap file ownership

`swapon` rejects a user-owned swap file:

```text
swapon: ... insecure file owner 1000, 0(root) suggested
```

Fix the owner and permissions before enabling it:

```bash
sudo chown root:root /home/xmut1613/wuqiang/riscv_codex_builds/codex-build.swap
sudo chmod 600 /home/xmut1613/wuqiang/riscv_codex_builds/codex-build.swap
sudo swapon /home/xmut1613/wuqiang/riscv_codex_builds/codex-build.swap
```

Do not commit the swap file.

### Memory readings

Low `free` memory is not automatically an OOM condition on Linux. Watch
`available` memory and swap growth instead. During this build, ordinary
parallel Rust compilation with `CARGO_BUILD_JOBS=4` stayed within memory once
swap was enabled.

The real peak happened during the final `codex-cli` link. Observed process
sizes:

```text
ld peak RSS: about 8.9 GiB
rustc retained RSS during link: about 5.5 GiB before pages were swapped out
swap peak: about 4.2 GiB of 8 GiB
```

If final linking is killed by OOM, retry from the existing Cargo cache with
linker memory-reduction flags:

```bash
export CARGO_BUILD_JOBS=4
export RUSTFLAGS="-C link-arg=-Wl,--no-keep-memory -C link-arg=-Wl,--reduce-memory-overheads"
```

Only use this after an actual link failure, because changing `RUSTFLAGS` can
invalidate more cached work.

### C++ runtime symbols

The final link can fail with V8 C++ symbols such as:

```text
undefined reference to `operator new(unsigned long)'
undefined reference to `std::__throw_length_error(char const*)'
undefined reference to `vtable for __cxxabiv1::__si_class_type_info'
```

Using `g++` as the linker is necessary but not sufficient in this Cargo build:
the final Rust link still needs `libstdc++` explicitly. `scripts/build-codex.sh`
uses:

```bash
cargo "+${RUST_TOOLCHAIN}" rustc --release -p codex-cli --bin codex \
  --target "$RUST_TARGET" -- -C link-arg=-lstdc++
```

The script also sets native RISC-V builds to use `/usr/bin/g++` as the target
linker.

### PATH alias warning

Running the installed binary from the sandbox can print:

```text
WARNING: proceeding, even though we could not create PATH aliases: Read-only file system (os error 30)
```

This warning came from the restricted execution environment. The binary still
reported `codex-cli 0.144.1` and ran successfully.
