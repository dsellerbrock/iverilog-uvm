# Clause 29 dominance-control attempt 05

Slurm job 3695 completed in under one second but exited 1 on the output comparison. Although `dom_clk` started at 0 and was driven to 1, the edge-only UDP printed `EDGE x`; the job stopped after the `-g2017` comparison and did not run `-g2023`. This attempt is not valid §29.10 evidence.

The lead identified that unmatched time-zero input transitions can set the output to x before the tested edge. Attempt 06 first recovers the state through the level-sensitive clear row, checks an edge-only control, and then checks the overlapping rows. Raw scheduler output and logs are preserved in [`raw-slurm-3695/`](raw-slurm-3695/).
