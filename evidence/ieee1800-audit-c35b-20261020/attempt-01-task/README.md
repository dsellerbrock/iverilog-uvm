# Clause 35.4, 35.8, and 35.9 DPI task probe

This paired-edition probe checks `c_identifier` aliasing and conflicting C
signatures, an exported task called from context-imported C tasks, and the DPI
disable/acknowledgment protocol for imported tasks and functions. It uses the pinned toolchain's `svdpi.h` and
the documented `vvp -d` shared-library loader. Inputs are in `input/`; raw
compiler, linker, runtime, output, version, and hash records are under
`remote-3558/`.

The SystemVerilog sources are in `tests/1800_audit/c35/`. Expected positive
output in each edition:

```text
A1 9
T1 5
T2 1 16
F1 1
```

`NOT_REACHED` and `FUNCTION_NOT_REACHED` must not print. The imported task
acknowledges a disable by returning 1; the imported function separately calls
`svIsDisabledState()` and `svAckDisabledState()` as required by §35.9. The
duplicate-identifier source must fail to compile in each edition.

## Generated C source whitespace normalization

The captured `*.dpiexport.c` files below were normalized after the original probe. Only trailing whitespace and an extra final blank line were removed; captured compiler logs and simulator outputs remain byte-exact. The change is recorded by the commit titled `docs: normalize audit evidence whitespace`.

| Original staged SHA-256 | Normalized SHA-256 | File |
|---|---|---|
| `07de667052a9cb19cc743e3fa8f481d8f42840ed85aeb84d444aabcb545d4e8c` | `a3e2188003e27bf19b230681fbe24f9bc47c9fb75a082e84f2c094bb9170a800` | `evidence/ieee1800-audit-c35b-20261020/attempt-01-task/remote-3558/raw/p35_task-2017.dpiexport.c` |
| `07de667052a9cb19cc743e3fa8f481d8f42840ed85aeb84d444aabcb545d4e8c` | `a3e2188003e27bf19b230681fbe24f9bc47c9fb75a082e84f2c094bb9170a800` | `evidence/ieee1800-audit-c35b-20261020/attempt-01-task/remote-3558/raw/p35_task-2023.dpiexport.c` |
| `07de667052a9cb19cc743e3fa8f481d8f42840ed85aeb84d444aabcb545d4e8c` | `a3e2188003e27bf19b230681fbe24f9bc47c9fb75a082e84f2c094bb9170a800` | `evidence/ieee1800-audit-c35b-20261020/attempt-01-task/remote-3558/scratch/2017/p35_task.out.dpiexport.c` |
| `07de667052a9cb19cc743e3fa8f481d8f42840ed85aeb84d444aabcb545d4e8c` | `a3e2188003e27bf19b230681fbe24f9bc47c9fb75a082e84f2c094bb9170a800` | `evidence/ieee1800-audit-c35b-20261020/attempt-01-task/remote-3558/scratch/2023/p35_task.out.dpiexport.c` |
