# Ibex simulation-target replay

This focused replay used the same patched OpenTitan snapshot and Icarus engine
`367e` as the 309-row census. Both Ibex cores declare `sim` rather than
`default`; the matrix now selects that target and omits synthesis flags for
these simulation-only source lists.

| Core | Result | Detail |
|---|---|---|
| `lowrisc:ibex:tb_cs_registers:0` | `PASS` | Setup and Icarus compile pass. Its simulation-oriented warnings are already classified as benign. |
| `lowrisc:ibex:ibex_riscv_compliance:0.1` | `SETUP_FAIL` | FuseSoC cannot resolve the declared `lowrisc:ibex:sim_shared` dependency, which is absent from this OpenTitan source snapshot. |

The compiler driver and engine hashes match the base census. The focused
[result JSON](result.json) and [report](result.md) retain the runner output;
local copies of the setup and compile logs are linked below.

- [Compliance setup log](ibex_riscv_compliance-setup.log)
- [CSR test setup log](tb_cs_registers-setup.log)
- [CSR test compile log](tb_cs_registers-compile.log)

The merged [scope-reviewed aggregate](../result-scoped-aggregate.md) replaces
the old `tb_cs_registers` setup failure with this passing replay. The compliance
row remains a setup failure until the exact missing Ibex support core is
available.
