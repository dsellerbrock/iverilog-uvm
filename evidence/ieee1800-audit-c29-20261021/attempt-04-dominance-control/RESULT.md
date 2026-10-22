# Clause 29 dominance-control attempt 04

Slurm job 3694 on DAN-DESKTOP completed in under one second but exited 1 because the edge-only control printed `EDGE x`, not its expected `EDGE 1`, under `-g2017`. The mixed table printed `DOM 0`. Since the control did not demonstrate that its edge row fired, this attempt does not establish §29.10 dominance and is not counted as a conformance result. The run stopped before `-g2023`.

The exact source, expected output, compiler/runtime hashes, job state, and logs are preserved in this directory. Attempt 05 changes the control to a known rising edge and reruns both editions.
