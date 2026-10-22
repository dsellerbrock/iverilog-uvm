# Initial probe design check — Slurm job 3702

Both `-g2017` and `-g2023` produced the expected R1/R2/R4 observations:

```text
R1 act b=0
R2 inact b=0
R4 react b=1
```

The Postponed display showed `R5 post b=1 c=0 d=0`, while the test expected `c=2`. The source declared `c` as a scalar `logic`, so assigning 2 truncates to 0. This was a test-width mistake; it is not evidence of a simulator gap. The NBA-order observation needs the corrected two-bit control in attempt 02. Raw compiler/run logs and input copies are retained under [`raw-slurm-3702/`](raw-slurm-3702/).
