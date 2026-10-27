# §18.14.2 shuffle thread-stability probe with `$urandom` control

This reruns the schedule-reversal probe from attempt 03 and records one
`$urandom()` result in each sibling before its shuffle. The per-thread
`$urandom()` values match while the array orders change, isolating the result
to `shuffle()` rather than process seeding.

IEEE 1800-2017 §18.14.2 (p. 540) and IEEE 1800-2023 §18.14.2 (p. 562) both
specify that `shuffle()` results are independent of thread execution order.

Probe SHA-256: `3d62c114cdbc3bf8fed93c2c41dbbc722463cc5e17b6d0590aed3952f8b5aadc`.
Slurm job `3576` on `DAN-DESKTOP` compiled and ran both editions and both
schedules twice. All compiles/runs succeeded; each schedule replayed
identically. With `-g2017` and `-g2023`, the base schedule produced
`A_u=2719024023`, `A=0,5,7,3,2,6,1,4`, `B_u=3626304633`, and
`B=10,14,13,9,8,11,12,15`. Reversing which sibling was delayed retained both
`$urandom()` values but changed the arrays to `A=2,6,5,1,0,3,4,7` and
`B=8,13,15,11,10,14,9,12`.

Open+closed dedupe, refreshed 2026-10-20: GitHub issue searches for `shuffle`,
`thread stability`, `random stability`, `execution order`, and `18.14.2` found
open #852 (the unrelated acceptance of `reverse() with`) and closed #43 (a
broad array-methods issue). The broader `random stability` search also found
open #617, whose body identifies the distinct §8.12 shallow-copy RNG-state
gap and says §18.14 will be audited separately. None covers shuffle results
changing with sibling execution order; no equivalent open or closed issue was
found.

Raw compile/run logs and `result.txt` are retained under `logs/`.
