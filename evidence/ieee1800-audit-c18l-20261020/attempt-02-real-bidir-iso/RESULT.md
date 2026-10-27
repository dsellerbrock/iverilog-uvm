# IEEE 1800 real-predicate bidirectional isolation, Slurm job 3473

## Evidence

- DAN-DESKTOP Slurm job 3473, 1 CPU / 1 GiB, 2026-10-20T15:43:03Z–15:43:36Z (33 seconds). `-g2023` compile rc=0; simulator rc=0. Each process had a 60-second process-group timeout. Icarus 13.0-devel `cc25756d1`; binary and source hashes are under `remote-results/job-3473/results/`. Peak RSS is unavailable because Slurm accounting is disabled.
- Compile warnings: none.
- Raw D1–D5 output:

```text
D1 ok=0 bad=0
D2 ok=0 bad=0
D3 ok=0 bad=0
D4 ok=0 bad=0
D5 ok=0 bad=0
```

- Each case made five calls; every call failed. The runtime emitted the same diagnostic 25 times total, five per case: `ERROR: global constraint sampling failed: no feasible binary64 value satisfies the finite real interval.`
- D1 (point disjunction without `inside`) fails, matching #840's root cause. D2–D5 (negated real comparison, negated real truthiness, backward implication, and backward if–else inference) also fail. The lead classified all five as one point-set reduction gap: real solving succeeds for bound-derived intervals or direct equalities, while constraints reducing the real variable to isolated points through disjunction, negation, implication, or if–else fail. D2 is the discriminating case: `!(r != 0.0)` fails while direct `r == 0.0` passes.

## Dedupe

`dedupe-open-closed.txt` records all four lead-requested searches with `--state all`; #840 (discrete real `inside`) and #463 (remaining real-randomization forms) were directly reviewed. The lead classified the failures as the same gap as #840; no new issue was filed. The probe was posted to [#840](https://github.com/dsellerbrock/iverilog-uvm/issues/840#issuecomment-6294920349).
