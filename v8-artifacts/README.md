# V8 Artifacts

Prebuilt `rusty_v8` files are stored as GitHub Release assets because the
compressed static library is larger than GitHub's normal Git blob limit.

Download the current RISC-V artifact with:

```bash
scripts/download-rusty-v8-release.sh 149.2.0
```

That command writes files under:

```text
v8-artifacts/rusty-v8-v149.2.0-riscv64gc-unknown-linux-gnu/
```

`scripts/build-latest.sh` will reuse files from this directory when the
matching `rusty_v8` version is already present.
