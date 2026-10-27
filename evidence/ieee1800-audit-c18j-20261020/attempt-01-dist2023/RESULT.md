# IEEE 1800 distribution additions probes, Slurm jobs 3437–3438

## Evidence

- Standard: IEEE 1800-2017 §18.5.4 (pp. 512–513); IEEE 1800-2023 §18.5.3 (pp. 531–533).
- Host/resources: DAN-DESKTOP, 1 CPU / 1 GiB, 88 seconds (2026-10-20T15:06:44Z–15:08:12Z). Each compiler and runtime process had a 30-second process-group timeout. Peak RSS is unavailable because Slurm accounting is disabled.
- Follow-up: Slurm job 3438, DAN-DESKTOP, 1 CPU / 1 GiB, 17 seconds (2026-10-20T15:12:03Z–15:12:20Z), with 30-second process-group timeouts; raw outputs and timestamps are in [attempt 02](../attempt-02-default-3000/README.md).
- Compiler: Icarus 13.0-devel `cc25756d1`, SHA256 `1088dd266d4715d5a99d4eb5f7ae7a128449744927bae1971b37278872613593`; VVP SHA256 `e66837952db8927f4ef69007b4290c07e23f30f9258facae416da98c95715bbb`.
- Inputs/scripts and raw logs: `input/`, `SHA256SUMS-input.txt`, `remote-results/`. Full open+closed issue queries and results: `dedupe-open-closed.txt`.

## E1, E2, E3, E6

All these tests compiled and ran with return code 0 in both editions; output was identical:

```text
E1 100:2007 101:3998 102:1995 other=0
E2 100:1985 101:2011 102:2004 other=0
E3 102:6070 103:1930 other=0
E6 rc=1 x=5
```

- E1 demonstrates the 2023 additive-weight result 1:2:1. This behavior is outside what 2017 §18.5.4 specifies, so the 2017 result is recorded without a conformance claim.
- E2 demonstrates that in 2023 the zero-weight occurrence does not exclude 100 when the same value also occurs in a nonzero-weight range.
- E3 is expected near 6000:2000 (3:1) in 2023 and 4000:4000 (1:1) in 2017. The observed 2023 result matches, but the 2017 result also matches 3:1, contrary to 2017's per-value range rule. This is a candidate edition-gating gap.
- E6 confirms that a soft distribution yields to the hard inline constraint in both editions.
- Positive compile logs are empty.

## E4 `default :/` and negative syntax tests

- `p18_05_3_default.sv` is rejected under `-g2017` with the edition-gating diagnostic: `the default item in a dist constraint requires IEEE1800-2023`.
- Under `-g2023`, E4 compiles and runs successfully after reducing the sample count from 8000 to 3000: `E4 in=2255 out=745 distinct_out=243`, followed by `E4 t=0`. Counts match the expected `in=2250 ±119`, `out=750 ±119`, and `distinct_out >200`; `default :/` therefore distributes over the remaining range as required. The 3000 calls took 17.71 seconds real (17.52 user, 0.17 system).
- Performance observation only: E4 takes about 5.9 ms per `randomize()` versus about 2.5 ms for the E-series. This is not a conformance issue and is not recorded in `DISCOVERED_DEBT.md`.
- `default := 1` is rejected in both editions. A second `default :/` is rejected in both: 2017 rejects the 2023-only syntax; 2023 reports that a dist list may contain at most one default item.

## Dedupe and disposition

The searches found #836 for the separate no-`rand` rule and closed #12 for general weighted-`dist` support. `dist range weight excluded` and `dist additive weight` returned no direct match. The lead classified the edition mismatch as distinct and filed [#837](https://github.com/dsellerbrock/iverilog-uvm/issues/837) after this open+closed dedupe. The follow-up closes the E4 measurement gap; it produced no additional issue.
