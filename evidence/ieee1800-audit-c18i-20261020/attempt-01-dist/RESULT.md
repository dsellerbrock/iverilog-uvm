# Partial results: §18.5.4 distribution, Slurm job 3431

IEEE 1800-2017 §18.5.4 (pp. 512–513) and IEEE 1800-2023 §18.5.3 (p. 531). The 2017 text says `dist` is a membership test, `:=` weights each value in a range, `:/` weights a range as a whole, and zero weight is a constraint. Both editions prohibit applying `dist` to `randc` and require a `rand` variable in the expression.

**Environment:** DAN-DESKTOP, Slurm job 3431, 1 CPU / 1 GiB. Current-main Icarus 13.0-devel commit `cc25756d1`; compiler SHA256 `1088dd266d4715d5a99d4eb5f7ae7a128449744927bae1971b37278872613593`; VVP SHA256 `e66837952db8927f4ef69007b4290c07e23f30f9258facae416da98c95715bbb`. Started `2026-10-20T14:54:03Z`, ended `2026-10-20T14:55:07Z` (64 seconds). Each process used the process-group timeout helper with a 30-second limit.

## Runtime output

Both `-g2017` and `-g2023` compiled the positive probe successfully, then the combined simulation hit the 30-second timeout while continuing into D3. D1 and D2 had printed:

```text
D1 100:1020 200:1985 300:4995 other=0
D2 100:1007 200:0 300:4993 other=0
```

Both distributions are within the lead's pass windows. D3–D7 were not reached in this attempt. The raw stdout and compile warnings are in `remote-results/logs/`; the tabulated exit codes are in `remote-results/positive.tsv`.

## Negative compile results

`p18_05_4_n1_randc.sv` failed in both editions with the required diagnostic:

```text
error: 'randc' variables cannot be used in 'dist' constraints.
```

`p18_05_4_n2_norand.sv` compiled successfully in both editions, contrary to the §18.5.4 / §18.5.3 rule requiring at least one `rand` variable. The logs contain only an unrelated static-initialization warning in this first attempt; the follow-up input removes it.

## Dedupe

Open+closed search output is in `dedupe-open-closed.txt`. The `dist in:title`, `distribution constraint`, and `randc dist` searches surface closed issue #12, whose scope includes general `dist` weighted distributions. The other recorded searches return no matching issue. Lead classification is pending until D3–D7 complete.

SHA256s for staged inputs and the run script: `SHA256SUMS-input.txt`. The run's compiler/runtime hashes are in `remote-results/SHA256SUMS`.
