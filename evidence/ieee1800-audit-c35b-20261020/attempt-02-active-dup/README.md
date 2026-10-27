# Active duplicate `c_identifier` reproducer

This rerun strengthens the initial §35.4 negative case by calling both imported
routines that share `c_add2` but declare incompatible signatures. Compilation
must still reject the declarations before runtime linking is attempted. The
same paired-edition runtime probe also checks the legal alias, exported tasks,
and distinct §35.9 task/function disable paths.

## Generated C source whitespace normalization

The captured `*.dpiexport.c` files below were normalized after the original probe. Only trailing whitespace and an extra final blank line were removed; captured compiler logs and simulator outputs remain byte-exact. The change is recorded by the commit titled `docs: normalize audit evidence whitespace`.

| Original staged SHA-256 | Normalized SHA-256 | File |
|---|---|---|
| `07de667052a9cb19cc743e3fa8f481d8f42840ed85aeb84d444aabcb545d4e8c` | `a3e2188003e27bf19b230681fbe24f9bc47c9fb75a082e84f2c094bb9170a800` | `evidence/ieee1800-audit-c35b-20261020/attempt-02-active-dup/remote-3559/raw/p35_task-2017.dpiexport.c` |
| `07de667052a9cb19cc743e3fa8f481d8f42840ed85aeb84d444aabcb545d4e8c` | `a3e2188003e27bf19b230681fbe24f9bc47c9fb75a082e84f2c094bb9170a800` | `evidence/ieee1800-audit-c35b-20261020/attempt-02-active-dup/remote-3559/raw/p35_task-2023.dpiexport.c` |
| `07de667052a9cb19cc743e3fa8f481d8f42840ed85aeb84d444aabcb545d4e8c` | `a3e2188003e27bf19b230681fbe24f9bc47c9fb75a082e84f2c094bb9170a800` | `evidence/ieee1800-audit-c35b-20261020/attempt-02-active-dup/remote-3559/scratch/2017/p35_task.out.dpiexport.c` |
| `07de667052a9cb19cc743e3fa8f481d8f42840ed85aeb84d444aabcb545d4e8c` | `a3e2188003e27bf19b230681fbe24f9bc47c9fb75a082e84f2c094bb9170a800` | `evidence/ieee1800-audit-c35b-20261020/attempt-02-active-dup/remote-3559/scratch/2023/p35_task.out.dpiexport.c` |
