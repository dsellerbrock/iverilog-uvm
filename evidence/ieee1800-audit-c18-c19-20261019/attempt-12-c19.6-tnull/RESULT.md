# IEEE 1800 §19.6 corrected ownership probes — Slurm attempt 12

- Job 2991 on DAN-DESKTOP, 1 CPU / 1 GiB, 1 second; `GATE_RESULT=FAIL` because one expected-negative probe compiled.
- Pinned toolchain hashes match the recorded main toolchain in attempt 09.
- Positive cross probe compiled and ran successfully in -g2017 and -g2023; all seven checks passed (explicit and implicit crosses, iff guard, user bins, auto-bin retention).
- Direct expression cross was rejected in both editions with syntax error and unsupported-item diagnostic.
- Cross from another group by hierarchical reference `cross one.ca, cb;` **unexpectedly compiled** in both -g2017 and -g2023 (exit 0, empty stderr). This is the §19.6 ownership gap to classify.
- Type-scoped `first::ca` was rejected in both editions with a syntax error.
- Negative tests compiled with `-tnull`, so no root-module selection failure.
- Source archive, exact runner, statuses, compiled output, and raw logs are retained in `results/`.
