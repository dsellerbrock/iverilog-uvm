# IEEE 1800-2023 real-set and uniqueness controls, Slurm job 3458

## Standards

- IEEE 1800-2023 §11.4.13, p. 288: `inside` tests each listed expression/value range for a match; for nonintegral expressions it uses equality.
- IEEE 1800-2023 §18.5.4, p. 534: `unique` accepts singular real variables and unpacked arrays/slices with real leaves.

## Evidence

- DAN-DESKTOP Slurm job 3458, Icarus 13.0-devel `cc25756d1`, 1 CPU / 1 GiB, 2026-10-20T15:29:26Z. Compile and runtime each had a 30-second process-group timeout. Slurm accounting is disabled, so peak RSS is unavailable.
- `-g2023` compile rc=0 and runtime rc=0. Output:

```text
R1 ok=0 bad=0 R1P rc=0 C0 ok=0 bad=0
C1 ok=100 bad=0 C2 ok=100 bad=0 C3 ok=0 bad=0
```

- C0 (real `inside {1.0,2.0,3.0}` without `unique`) and C3 (the same inside sets with explicit `r1 != r2`) both fail every randomization. C1 (real interval bounds) and C2 (`unique` over real interval variables) each succeed 100/100. This isolates the R1 failure to real set-membership handling rather than `unique`. R1P is not independently interpretable because its discrete real set is affected by the same failure.
- Exact repeated runtime diagnostic: `ERROR: global constraint sampling failed: no feasible binary64 value satisfies the finite real interval.`
- Raw logs, tool hashes, and result metadata are under `remote-results/`. Dedupe output for open and closed issues is `dedupe-open-closed.txt`.
- Existing [#463](https://github.com/dsellerbrock/iverilog-uvm/issues/463) is open; its body covers remaining real randomization forms, arrays/aggregates, and distribution, but does not specifically mention real `inside` value sets. The lead filed [#840](https://github.com/dsellerbrock/iverilog-uvm/issues/840) for this narrower gap after the open+closed dedupe; #840 cross-references #463.
