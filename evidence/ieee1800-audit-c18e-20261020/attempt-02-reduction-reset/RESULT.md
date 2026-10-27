# §18.5.8 iterative-constraint probe, attempt 2

**Host:** DAN-DESKTOP Slurm, job 3389, 2026-10-20. **Input base:** `cc25756d187314742d347267c2a513b3e640a7fb`. **Compiler:** Icarus Verilog 13.0-devel (`cc25756d1`); binary SHA-256 `1088dd266d4715d5a99d4eb5f7ae7a128449744927bae1971b37278872613593`; `vvp` SHA-256 `e66837952db8927f4ef69007b4290c07e23f30f9258facae416da98c95715bbb`.

The runner compiled and ran the positive probe with `iverilog -g2017` and `-g2023`; both returned 0 and printed `RESULT pass=6 fail=0`. The probe checks per-element `foreach` constraints, constrained dynamic-array size, guarded ascending order, array `sum() with`, 2-D indexing, and an index expression. Each compile/run process had a 20-second timeout.

Two negative probes target the explicit requirements in 2017 §18.5.8.1 pp. 516–517 and 2023 §18.5.7.1: a loop variable cannot share the array's identifier, and the number of loop variables cannot exceed array dimensions. Both forms compiled with rc=0 in both editions. The same-identifier form emitted no diagnostic. The extra-dimension form emitted only a warning that the constraint is not representable by the solver; it did not reject compilation. The lead must decide whether the constraint-context gaps are covered by existing #783, which reports the corresponding §12.7.3 procedural-`foreach` validation gaps.

Raw compile/runtime logs, TSV exit codes, source/tool hashes, and the exact Slurm script are in this directory. Slurm accounting is disabled and `seff` is unavailable, so elapsed time, peak RSS, and final scheduler exit status could not be recovered after the job left `squeue`; per-test compile/run exit codes are recorded in `slurm-results/{positive,negative}.tsv`.

## Open/closed issue dedupe for #830 (2026-10-20)

Searched all repository issues in both states for `foreach constraint`, `constraint foreach`, and loop-variable dimension rules. Open #783 covers the parallel validation gaps in procedural `foreach` (§12.7.3), not constraint-expression `foreach` (§18.5.8.1 / 2023 §18.5.7.1). Closed #487 concerns packed-rank traversal, not loop-variable validation. No existing issue covers these constraint-context cases.
