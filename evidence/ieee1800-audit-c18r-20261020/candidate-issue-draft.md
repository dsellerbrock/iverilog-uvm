# NOT FILED — lead review required

## Candidate

**Title:** `[IEEE 1800] §18.14.2 — shuffle() results depend on sibling thread execution order`

**Expected behavior:** IEEE 1800-2017/2023 §18.14.2 says `shuffle()` results are independent of thread execution order.

**Reproduction:** `tests/1800_audit/c18/p18_14_shuffle_stability.sv`, using `-g2017` and `-g2023`, with the paired builds from `evidence/ieee1800-audit-c18r-20261020/attempt-04-shuffle-urandom-control/run.sbatch`. Both builds use `+ntb_random_seed=123456789`; the parent process calls `process::self().srandom(101)`. One run delays sibling A and the other delays sibling B. Each variant was run twice.

**Observed on:** source commit `fb584a251dd4cc91e56a75be662ccd5ee05c64e9`, Icarus 13.0-devel, `iverilog` SHA-256 `9760f8c1ab8ad03d64761b257db74ff07603a15c4d44d2bcdba75073f006911c`, Slurm job 3576 on `DAN-DESKTOP`.

Both editions compiled and ran successfully; each schedule replayed identically. The per-thread `$urandom()` controls matched across schedules (`A_u=2719024023`, `B_u=3626304633`), but the shuffled arrays changed:

- A delayed: `A=0,5,7,3,2,6,1,4`; `B=10,14,13,9,8,11,12,15`
- B delayed: `A=2,6,5,1,0,3,4,7`; `B=8,13,15,11,10,14,9,12`

The same values were observed under `-g2017` and `-g2023`. Raw outputs are under `evidence/ieee1800-audit-c18r-20261020/attempt-04-shuffle-urandom-control/logs/`.

## Open+closed dedupe

Searched all repository issues across open and closed states for `§18.14.2`, `shuffle stability`, `shuffle()`, `thread stability`, `random stability`, `execution order`, and `shuffle results`. The only match was open #852, about the distinct `reverse() with` restriction. The audit-label search also found #833, about duplicate `randsequence` defaults. No existing issue covers `shuffle()` random stability across sibling scheduling order.
