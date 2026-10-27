# Clauses 18.12 and 19.4.1 probe results

- Slurm job 2897 on DAN-DESKTOP, 1 CPU / 2 GiB, exit `0:0`, elapsed 2 seconds. Peak RSS was not retained by Slurm accounting.
- Base commit: `82023726be90ab269d6e0ef5e755ebb69e6f648c`; Icarus 13.0 devel SHA-256 `234d4e6ee4a27f636b1b07de19e31db0ea510601945ed5aaf2885edb8e1d4f42`; VVP SHA-256 `2c18f1c5cfc8519fc72ede80878efb500d3187c681472c5935f3bb59388e0350`.

## §18.12

- Positive scope-randomize probe passed with `-g2017` and `-g2023`, printing `PASS scope randomize clause 18.12`.
- The no-argument `std::randomize() with` checker probe was rejected in both editions with `No function named std.randomize found in this context`; tracked by [#681](https://github.com/dsellerbrock/iverilog-uvm/issues/681).
- The invalid expression argument `std::randomize(a + 1)` compiled and ran in both editions; tracked by [#682](https://github.com/dsellerbrock/iverilog-uvm/issues/682). Existing null-argument gap is tracked by [#621](https://github.com/dsellerbrock/iverilog-uvm/issues/621).
- The separate `std::randomize(null)` probe compiled and ran in both editions; details and raw logs are in [attempt 3](attempt-03.md).

## §19.4.1

- All 41 JSON tests matching `sv_covergroup_class_inheritance*` passed, including inheritance reuse, cross-bin resolution, sample dispatch, property shadowing/bounds, and the targeted parameterized-extension diagnostic.
- The 2023 feature is supported for non-parameterized embedded covergroups. Specialized parameterized extensions remain explicitly unsupported and are tracked by [#659](https://github.com/dsellerbrock/iverilog-uvm/issues/659).

Raw logs and per-test results: `audit-probes-attempt-02.tar.gz`. Probes: [§18.12 positive](../../../tests/1800_audit/c18/p18_12_scope_randomize.sv), [§18.12 zero-argument gap](../../../tests/1800_audit/c18/neg/n18_12_scope_randomize_no_args.sv), [§18.12 expression-argument gap](../../../tests/1800_audit/c18/neg/n18_12_scope_randomize_expr.sv). Runner: `audit-probes.sbatch`.
