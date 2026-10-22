# IEEE 1800 implication and if–else probe, Slurm job 3472

## Standards

- IEEE 1800-2017 §§18.5.6–18.5.7, pp. 514–515: implication and if–else constraint predicates are integral expressions.
- IEEE 1800-2023 §§18.5.5–18.5.6, pp. 535–536: the predicate may be integral or real.

## Evidence

- DAN-DESKTOP Slurm job 3472; 1 CPU / 1 GiB; each compiler/runtime process had a 30-second process-group timeout. Icarus 13.0-devel `cc25756d1`; binary hashes, source hashes and raw output are in `remote-results/job-3472/results/`. Peak RSS is unavailable because Slurm accounting is disabled.
- Integral probe compiled and ran successfully under both `-g2017` and `-g2023`; all functional checks reported zero errors: I1 `a0=325 bad=0`, I1_BIDIR `bad=0`, I2 `bad=0`, F1 `bad=0`, F1_BIDIR `bad=0`, F2 `bad=0 m1_free=183`, F3 `bad=0`.
- The 2017 state-real predicate control compiled and ran (`Q b=1`) under both `-g2017` and `-g2023`. The lead classified the 2017 acceptance as permissive edition gating: §18.5.6 describes the permitted integral predicate but does not require a diagnostic, and the behavior is semantically correct. No issue is filed.
- In `-g2023`, P1 state-real predicate cases passed: `P1_W05 bad=0`, and for false predicate `P1_W0 fail=0`, `b0=87 b1=113`. P2 with `r==0.5` and `r==0.0` inline constraints each reported `bad=0`.
- P2_BIDIR did not complete within 30 seconds. The runtime emitted the exact diagnostic `ERROR: global constraint sampling failed: no feasible binary64 value satisfies the finite real interval.` 34 times before the timeout. The output contains no P2_BIDIR summary; this is an incomplete probe result, not a completed 100-sample measurement.
- F2 has 576 legal (mode,len) pairs: 10 for mode 0, 256 for mode 1, and 155 each for modes 2 and 3. `m1_free` counts the mode-1 pairs with `len<=100`, so its expected count is 175 ±60 over 1,000 samples (5σ); the observed 183 conforms. The lead confirmed the initial estimate near 99 was incorrect.

## Lead classification

- Integral implication and if–else behavior is conforming in both editions for the tested cases. The §18.5.7 / 2023 §18.5.6 row is IMPLEMENTED (tested subset).
- 2023 real predicate support is PARTIAL pending the isolated shared finite-real-disjunction failure in [attempt 02](../attempt-02-real-bidir-iso/RESULT.md). §18.5.6 / 2023 §18.5.5 remains PARTIAL; see the matrix row.
- The total audit issue count remains 105 at this checkpoint.

## Dedupe

`dedupe-open-closed.txt` records exact open+closed searches over the repository and the full 347-issue inventory snapshot. It found no direct real-predicate or implication/if–else hit. The closed #417 covers uniformity of constrained dynamic-array tuples; open #463 covers remaining real randomization forms; open #840 is specifically discrete real `inside` sets. These were inspected as possible overlaps. Lead classification and any issue filing are pending.
