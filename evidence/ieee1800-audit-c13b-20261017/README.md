# IEEE 1800 clause 13 probe c13b

Probe scope: §13.5.4 named argument binding and §13.5.5 optional argument lists, with 2017/2023 comparison; the no-parentheses footnote was also checked.

Attempt 01 ran on DAN-DESKTOP, Slurm job 2295 (1 CPU, 1 GiB, 10-minute cap; per compile 60 seconds and per simulation 30 seconds, TERM then KILL after 2 seconds). It completed with `ExitCode=0:0`. Icarus 13.0 devel from protected source `9b5fad2af`; binary hashes and exact staged source hashes are in [`attempt-01/manifest.txt`](attempt-01/manifest.txt).

The positive probe passed all 14 checks in both editions (`DONE fails=0`): nine named/positional/default argument cases plus no-parentheses calls for a void function, a defaulted void function, a task, a void class method, and a non-void class method. The negatives for positional-after-named, missing required named formal, and unknown named formal all rejected with the expected diagnostics. The audit lead classified §§13.5.4 and 13.5.5 as IMPLEMENTED in both editions. The bare non-void function name without parentheses is rejected; its diagnostic is weak (an unresolved-binding warning followed by elaboration failure), but it is not a conformance gap.

Full raw compile/run output and per-case logs: [`attempt-01/logs/results.txt`](attempt-01/logs/results.txt) and sibling `*.log` files. Exact submitted job script: [`attempt-01/a3-m7-c13b.sbatch`](attempt-01/a3-m7-c13b.sbatch).
