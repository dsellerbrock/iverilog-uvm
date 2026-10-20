# Final-head Slurm correctness gate

Pinned WP7 measurement base: `8c95b5cc10fc83d15b47e0364d2d7b4a2e12cac1`.
Exact final PR source: `da8813d6c68d6c73708cd4751ecdc67821dc1964`. This is a
correctness rerun after the single authorized rebase; no performance timings
were repeated.

Slurm job 3417 ran on DAN-DESKTOP with 4 CPUs and 8 GiB. It cloned the exact
PR commit, checked out all submodules, built and installed Icarus plus the real
UVM DPI library, then ran the required gates. All stages exited 0:

| Stage | Result |
| --- | --- |
| `make check` | pass |
| FPGA target install | pass |
| Full ivtest gate | pass: 4,804 JSON cases, 0 failures |
| Real-DPI UVM | pass: 367 passed, 0 failed, 0 skipped |

The copied run script is `final-head-gates.sbatch`; its SHA-256 is recorded in
`evidence-files.sha256`. `provenance.txt`, binary hashes, stage logs, timings,
and job results are preserved here. The remote job's `results/SHA256SUMS`
validates the copied gate and result files.
