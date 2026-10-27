# §19.6 ownership probes — Slurm attempt 11 (harness error)

- Job: 2990 on DAN-DESKTOP, 1 CPU / 1 GiB, 1 second, exit 0.
- Positive probe compiled and passed all checks in both -g2017 and -g2023.
- Direct expression cross was rejected in both editions.
- The type-scoped ownership probe `first::ca` was rejected in both editions with a syntax error.
- The hierarchical ownership probe is **inconclusive**: the runner invoked `iverilog -s test`, but the file's top module is `test_other_cg_hier`; Icarus rejected the missing selected root before testing cross syntax. The script incorrectly counted this as an expected rejection.
- Attempt 12 corrects the negative compile command to `-tnull`. Do not classify §19.6 from the attempt-11 hierarchical result.
- Full raw logs are in `results/`.
