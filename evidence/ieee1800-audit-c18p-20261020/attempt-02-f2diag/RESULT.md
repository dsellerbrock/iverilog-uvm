# IEEE 1800 constraint-function ordering — F2 diagnostic

## Standards

- IEEE 1800-2017 §18.5.12, p. 521; IEEE 1800-2023 §18.5.11.
- Random variables passed to a constraint function establish implicit
  ordering. The function result is state; further constraints can therefore
  expose whether that order is honored.

## Environment and evidence

- DAN-DESKTOP, Slurm job 3489, 1 CPU / 1 GiB, Icarus 13.0-devel `cc25756d1`.
- Both editions compiled and ran successfully. Each process had a 30-second
  process-group timeout. Raw logs, timing/RSS, hashes and timestamps are under
  `remote-results/job-3489/`.

## Results

Both editions produced identical results:

- D0: `lowpop=21` among 400 unconstrained F1 randomizations, near the expected
  22; this does not indicate a high-popcount sampling bias.
- D1: fixed `v=3` (popcount 2) succeeds: `rc=1`, `len=2`.
- D2: fixed `v=1023` (popcount 10) fails: `rc=0`, as expected. The displayed
  `v` and `len` remain at the prior D1 values after failure.
- D3: all 20 unconstrained F2 calls return `rc=0`; each retains the previous
  `v=3`, `pop=2`, `len=2` values.
- D4: a fresh class with the function equality and `length < 3` in separate
  constraint blocks also yields `ok=0 bad=0` over 200 calls.

The D3 and D4 failures occur despite legal solutions. The lead filed
[#844](https://github.com/dsellerbrock/iverilog-uvm/issues/844) for the silent
failure when a constraint further restricts a function-result variable.

## Dedupe

Six additional open and closed searches covering function-result state,
implicit ordering, and joint randomization returned no matches. The earlier
search in `../attempt-01-func/dedupe-open-closed.txt` found #680 and #494;
direct review showed those cover non-rand inline-function arguments and
queue-size leaves, respectively, not this failure.

The audit total after #844 is 109 issues: §6 38, §10 2, §11 8, §12 7, §15 2,
§18 13, §19 1, §20 12, §21 11, §23 5, §25 7, §26 1, and §27 2. This tranche's
new issue is under 2017 §18.5.12 / 2023 §18.5.11.
