# Clause 37 variable and instance-scope probes

This follow-up separates four cases so unreferenced-variable visibility, `reg` iteration, and parent-instance relationships can be classified independently. Each source runs the same VPI probe under `-g2017` and `-g2023`. The first attempt (`attempt-01-objmodel`, Slurm job 3683) was harness-only because its fixture did not call the registered system task. The first corrected attempt (`attempt-01-objmodel`, job 3684) showed matching ports and parameter values, but did not preserve an unused `logic` declaration in the observed iterator and returned `sub` for both `vpiScope` and `vpiModule` on child instance `u`.

The four inputs are `p37_var_unref.sv`, `p37_var_ref.sv`, `p37_reg.sv`, and `p37_scope.sv`. The first two compare an unused variable with one referenced by `$display`; the third compares `reg`; the fourth isolates child-instance relations. The C probe reports every `vpiVariables` and `vpiReg` result, the child instance full name, and the full names returned by `vpiInstance`, `vpiScope`, and `vpiModule`. `vpiInstance` is declared by the public `sv_vpi_user.h` header (constant 745), not `vpi_user.h`.

Pinned toolchain: `/home/dsell/toolchains/iverilog-fb584a25-20261020`, source `fb584a251dd4cc91e56a75be662ccd5ee05c64e9` (Icarus 13.0-devel). Slurm request: 1 CPU, 1 GiB, 5 minutes; each subprocess has a wall-clock timeout.
