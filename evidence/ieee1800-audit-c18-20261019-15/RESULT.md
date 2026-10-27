# §18.15 manually seeding probe

IEEE 1800-2017 §18.15 (p. 542) and IEEE 1800-2023 §18.15 (p. 564) specify per-object random generators, hierarchical object seeding from the creating thread, and manual object seeding through `srandom()`. The `srandom(int seed)` prototype is also specified in §18.13.3.

- Host: DAN-DESKTOP; Slurm job 3023; 1 CPU, 2 GiB requested; start/end UTC: `2026-10-19T10:08:19Z`.
- Toolchain: Icarus 13.0 devel, commit `cae03564`; `iverilog` SHA-256 `6f64b9987e04069dde9904cd1f0790d3430e34dbebb7908db159e6ec5290e330`; `vvp` SHA-256 `979d745f46bf952c86b1f09255e2256a6eec2bbef15b5c11634c8b4c95013309`.
- Positive probe: [`p18_15_srandom.sv`](../../tests/1800_audit/c18/p18_15_srandom.sv) checks internal seeding in `new`, external reseeding, repeatable sequences including seed 0, and isolation from `$urandom` and another object's randomization. It compiled and ran in both editions and printed `PASS srandom clause 18.15`.
- Negative probe: [`n18_15_srandom_no_args.sv`](../../tests/1800_audit/c18/neg/n18_15_srandom_no_args.sv) failed compilation in both editions with `srandom() method takes 1 arguments, got 0`.
- Every compile and simulation command had a 30-second timeout. Positive compile/run exit codes were 0 in both editions; negative compile exit codes were 1 in both editions. Per-command wall times and peak RSS are retained in `results/`.
- Hierarchical creation-thread seeding is also exercised by the paired-edition `p18_14_stability.sv` probe from Slurm job 2960. That evidence used ancestor commit `82023726be90ab269d6e0ef5e755ebb69e6f648c`; no randomization or thread source files changed from that commit to `cae035642e056644274a01e98d4422ce286685b4`.

Classification: `IMPLEMENTED (tested subset)`. Raw commands, version text, hashes, Slurm output, and per-edition logs are preserved in `results/`. The first attempt's extra static-initialization warning was removed by moving object construction into the `initial` block; its logs remain under `attempt-01-results-with-warning/` and are superseded by the final job 3023 results.
