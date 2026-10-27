# §18.17 randsequence probe, attempt 1

**Host:** DAN-DESKTOP Slurm, job 3395, 2026-10-20. **Input base:** `cc25756d187314742d347267c2a513b3e640a7fb`. **Compiler:** Icarus Verilog 13.0-devel (`cc25756d1`); compiler SHA-256 `1088dd266d4715d5a99d4eb5f7ae7a128449744927bae1971b37278872613593`; `vvp` SHA-256 `e66837952db8927f4ef69007b4290c07e23f30f9258facae416da98c95715bbb`. Compile and runtime processes had 30-second timeouts. Slurm accounting is disabled and `seff` is unavailable, so scheduler exit metadata, elapsed time, and peak RSS could not be recovered; per-test exit codes and logs are preserved.

The positive probe compiled and ran in both editions with `RESULT pass=5 fail=0`. The 3:2 production weights produced add=287/dec=213 of 500 in both editions; all four legal sequence outcomes, the corrected depth-2 if/else sequence, case selection, and repeat count passed.

The §18.17.3 negative with two `default` statements compiled without diagnostics in both editions (`compile_rc=0`). The corrected reducer in [attempt 2](../attempt-02-duplicate-default-runtime/RESULT.md) confirms it also runs with rc=0 in both editions; the one-default control compiles, runs, and prints `DEFAULT`. No issue has been filed yet.
