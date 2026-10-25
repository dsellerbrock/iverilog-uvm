# Clause 35 basic DPI import/export probe

Clause 35's matched 2017/2023 table-of-contents entries are recorded in [STANDARD.md](STANDARD.md). The probe source and shared-library build are in `tests/1800_audit/c35/`; it uses the documented `vvp -d` loader and the pinned toolchain's `svdpi.h`. Both editions ran with separate generated `.dpiexport.c` companions; the result is in [RESULT.md](RESULT.md).

Expected output:

```text
D1 5
D2 3.0
D3 hi bob
D4 7
D5 50
```

## Generated C source whitespace normalization

The captured `*.dpiexport.c` files below were normalized after the original probe. Only trailing whitespace and an extra final blank line were removed; captured compiler logs and simulator outputs remain byte-exact. The change is recorded by the commit titled `docs: normalize audit evidence whitespace`.

| Original staged SHA-256 | Normalized SHA-256 | File |
|---|---|---|
| `e47f5ba97059962932e54474d2c6ea3fdf9e4a2d1df6d2b7e91e47f5870a1b5f` | `2ac1ea767dc63a4c05af3613a4a080602333da853d84fbc7c95bc9e2a66aa5b8` | `evidence/ieee1800-audit-c35a-20261020/attempt-01-basic/remote-3557/raw/p35_basic-2017.dpiexport.c` |
| `e47f5ba97059962932e54474d2c6ea3fdf9e4a2d1df6d2b7e91e47f5870a1b5f` | `2ac1ea767dc63a4c05af3613a4a080602333da853d84fbc7c95bc9e2a66aa5b8` | `evidence/ieee1800-audit-c35a-20261020/attempt-01-basic/remote-3557/raw/p35_basic-2023.dpiexport.c` |
