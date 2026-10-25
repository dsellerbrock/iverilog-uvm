# Attempt 08 — Clause 7 probes on current main

- Source commit/tree: `8c95b5cc10fc83d15b47e0364d2d7b4a2e12cac1` / `817b904c91f8b7d302fcb12da3c12aa5d1814dd0` (same tree as T2 staging commit `6604c23e`).
- Slurm job 3247 on DAN-DESKTOP; 1 CPU, 1 GiB, 20-minute limit. Six probes were compiled and run in `-g2017` and `-g2023`; every compile returned 0.
- Toolchain SHA-256: `iverilog` `f8c0376ed73753c3327b1d7f5d4d647820836799064d965be7e1a8fbb9403ccd`; `vvp` `53ad297f5370175e0df8af51c5947b7b34c723cf258617febf716cf82168249b`.
- Both editions passed the memory word read/write, whole-array and packed-vector assignments, array argument mapping, and the tested associative-array methods/literals.
- The inactive tagged-member probe emits the required run-time error on stderr in both editions (`tagged union ... member 'integer_value' is inactive`) and returns an X result, matching IEEE 1800-2017/2023 §§7.3.2 and 11.9.
- The original invalid-index probe returned 1 in both editions because the invalid X/Z wildcard-index write allocated an associative entry. It exited before the later missing-read check, so attempt 08 makes no claim about missing reads or their warning.
- Result manifest verified all 50 files. Archive SHA-256: `62a073149327ae41721a9c0f0f1fc552b250464028ed96d0d67a8c953147d205`; Slurm log SHA-256: `13fb2b473b47b6d57347b24ab340654f10e845dfb838ac4672b46d496f96ea15`. Slurm accounting is disabled, so scheduler elapsed/exit status was unavailable.
- Saved results and logs are under `results/` and `raw-archive/`; the remote run root was removed after verification.
- The local-only probe input archive (`input/probes.tar.gz`, 8,205,854 bytes) is excluded from the PR; SHA-256: `ab9862aaae0acf1086933f692c14571f1b761469aac5c87c3e94c0bb23d00e59`.
