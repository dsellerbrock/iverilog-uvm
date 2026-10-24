# IEEE 1800 §19.11.2 cross coverage probe

- Standard: IEEE 1800-2017 §19.11.2, p. 588; IEEE 1800-2023 §19.11.2, p. 616. The relevant formula and zero-denominator rules match in both editions.
- Positive probe: `p19_11_2_cross_computation.sv` checks automatic cross bins, a merged user bin with denominator `Bc + Bu = 3`, zero-weight coverage, and the specified zero-denominator results.
- Boundary probe: `n19_11_2_two_arg_cross.sv` records whether a cross item accepts the two-argument `get_inst_coverage` overload.
- Toolchain: pinned main at `cae035642e056644274a01e98d4422ce286685b4` from `/home/dsell/toolchains/iverilog-uvm-m18-main-cae035642e056644274a01e98d4422ce286685b4/bin`.
- Slurm request: 1 CPU / 2 GiB, 20 minutes; each compile and run has a 90-second timeout. The tests use the shared toolchain read-only.
- Slurm job 3054 ran both positive probes successfully in 2017 and 2023, and the negative two-argument call failed in both editions. However, the harness used an invalid `[ ... || ... ]` conditional and exited 1; compile logs also included static-initialization warnings. Do not count this attempt as clean evidence.
- All job-3054 logs/results and its submitted script are preserved under `remote-job-3054/`. Retry with warning-free probes and corrected shell syntax is in attempt 20, job 3060.
