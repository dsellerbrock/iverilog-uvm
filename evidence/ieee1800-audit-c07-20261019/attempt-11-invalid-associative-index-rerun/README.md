# Attempt 11 — corrected §7.8.6 invalid-index probe

- Slurm job 3251 compiled in both editions. The corrected missing-entry check passed: a missing 2-state `int` read returned 0 without allocating an entry, and stderr contained the required nonexistent-entry warning.
- The subsequent write through wildcard key `4'bx001` allocated an entry in both editions, triggering the probe's failure. Stderr contained only the missing-read warning; no invalid-write warning was issued. IEEE 1800-2017/2023 §7.8.6 requires an invalid write to be ignored with a warning.
- Result manifest verified. Archive SHA-256 `f110fc55de26b3db1f1a4285edb085c6fd7ed863e9c139a0b0c49a42cf3e962f`; Slurm log SHA-256 `16756b0d3670592fc2c4874ac78973ac87bd5352afd721b131ac387b5f8b5b70`. Scheduler accounting is disabled.
- No matching issue was found during the repository issue search. The audit lead helper rejected classification/filed-issue requests at its daily cap (80); issue filing remains pending lead review.
