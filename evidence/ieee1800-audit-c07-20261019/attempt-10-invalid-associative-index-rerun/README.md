# Attempt 10 — invalid-index probe expectation correction

- Slurm job 3250 compiled the corrected-path probe in both editions, but the assertion expected a missing `int` entry to read as X. That expectation was wrong: IEEE 1800-2017/2023 §6.11.2 makes `int` a 2-state type, and Table 7-1 returns zero for a missing 2-state array element.
- The simulator returned zero and emitted the required §7.8.6 warning for the missing read. This run stopped at the probe's wrong X expectation and does not test the later invalid write.
- Result manifest verified; archive SHA-256 `92ec5d1ab1b1762fd2d8ee7f48efb1f0bb2dfb1bb2a443ca2cfd9b0097a18a2f`; Slurm log SHA-256 `454f2ec1096b1039347c3732781028eeed673166ca5ca8178661470158e2fafa`. Scheduler accounting is disabled.
