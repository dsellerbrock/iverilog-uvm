# Clause 13 c13a — attempt 02

Slurm job 2290 ran on DAN-DESKTOP (1 CPU, 1 GiB, 10-minute cap; per-compile timeout 30 s, per-run timeout 10 s, TERM then KILL after 2 s). It completed with `ExitCode=1:0` in one second because the harness found mismatches, not because of infrastructure loss. Icarus 13.0 devel from protected source `9b5fad2af`; hashes are in `manifest.txt`.

- `p13_05_args_core.sv`: all 15 checks passed in both `-g2017` and `-g2023` (`DONE fails=0`): by-value copy, ref variables/struct member/unpacked element/class property/object handle, visibility before return, const-ref read, positional empty defaults, and per-call evaluation of a default expression.
- Output and inout formal defaults both failed to compile in both editions with `sorry: Default arguments for subroutine output or inout ports are not yet supported.` The lead's proposed default-unresolved output probe therefore remains unsupported/inconclusive; the isolated input default with unresolved `nosuch` is rejected with an unresolved-reference warning and `Unable to evaluate nosuch as a port default expression` in both editions.
- An implicit static-lifetime function with a `ref` formal compiled in both editions (unexpected). The previous explicitly static function variant also compiled in both editions.

Raw per-case output: [`logs/results.txt`](logs/results.txt). Raw duplicate searches: [`duplicates.txt`](duplicates.txt). Exact submitted job script: [`a3-m7-c13a.sbatch`](a3-m7-c13a.sbatch). The 2017 printed p.332 §13.5.3 text confirms defaults may use input/inout/output/ref directions and that defaults are evaluated on each call; see `manifest.txt` for details.
