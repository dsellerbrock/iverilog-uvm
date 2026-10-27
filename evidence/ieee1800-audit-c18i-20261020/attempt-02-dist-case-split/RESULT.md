# IEEE 1800 distribution probe, Slurm job 3436

## Evidence

- Standard: IEEE 1800-2017 §18.5.4, pp. 512–513; IEEE 1800-2023 §18.5.3, p. 531.
- Source: Icarus 13.0-devel `cc25756d1`, compiler SHA256 `1088dd266d4715d5a99d4eb5f7ae7a128449744927bae1971b37278872613593`; VVP SHA256 `e66837952db8927f4ef69007b4290c07e23f30f9258facae416da98c95715bbb`.
- Host/resources: DAN-DESKTOP, 1 CPU, 1 GiB. Job ran 94 seconds, 2026-10-20T14:59:43Z–15:01:17Z. Each compile and each of seven simulation cases had its own 30-second process-group timeout. Peak RSS is unavailable (Slurm accounting is disabled).
- Inputs and commands are hashed in `SHA256SUMS-input.txt`; Slurm-side toolchain/input hashes are in `remote-results/SHA256SUMS`.

## Positive results

All positive compile and runtime return codes were 0 in both editions. Each output was identical for `-g2017` and `-g2023`:

```text
D1 100:1020 200:1985 300:4995 other=0
D2 100:1007 200:0 300:4993 other=0
D3 100:1003 101:1020 102:1008 200:2010 300:4959 other=0
D4 100:365 101:409 102:387 200:2243 300:5596 other=0
D5 1:0 2:400 other=0
D6 1:2970 2:1030 other=0
D7 rc=0
```

All counts are within the lead's windows; every unexpected-value count is zero. This tests direct weights and post-exclusion ratio, `:=` versus `:/` on a range, zero weights, a runtime weight expression, and the membership constraint behavior when another constraint requests an out-of-set value.

## Negative compile results

`p18_05_4_n1_randc.sv` failed as required in both editions:

```text
error: 'randc' variables cannot be used in 'dist' constraints.
```

`p18_05_4_n2_norand.sv` compiled with return code 0 and no diagnostics in both editions, contrary to the requirement that a `dist` expression contain at least one `rand` variable.

## Open and closed dedupe

All exact search commands and outputs are in `dedupe-open-closed.txt`. Relevant hits:

- #12 CLOSED, “Phase 8: Randomization completeness — dist, soft, solve..before, query forms,” covers general integer `dist` weighting and `:/`; its body excludes `randc` cycling and variable weights, and its comments record earlier distribution fixes and an unrelated §11.8.2 subject-expression follow-up.
- #8 CLOSED is the older Phase 2 `dist` implementation plan.
- #463 OPEN concerns expanding `rand real` intervals, not this rule.
- No exact §18.5.4 issue was found. Searches for the “requires at least one rand” and non-rand forms surfaced #12 only.

The 1800-audit lead classified the no-`rand` acceptance as a distinct gap and filed [#836](https://github.com/dsellerbrock/iverilog-uvm/issues/836) after reviewing the recorded open+closed searches. The combined first attempt is documented in `../attempt-01-dist/RESULT.md`; splitting by case was needed to keep each runtime process within 30 seconds.
