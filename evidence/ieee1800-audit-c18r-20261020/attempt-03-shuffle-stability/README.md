# §18.14.2 shuffle thread-stability probe

IEEE 1800-2017 §18.14.2 (pp. 541) and IEEE 1800-2023 §18.14.2 (pp. 562)
state that `shuffle()` results are independent of thread execution order.
`p18_14_shuffle_stability.sv` seeds one parent process, then runs two sibling
threads that shuffle distinct fixed arrays. The paired builds reverse which
sibling is delayed; the harness compares each labeled array result under both
editions and repeats each run with the same seed.

Probe SHA-256: `8edb38dfaebec90f88a73556c31b68219d0d4c4c4c9c87514dc270e7da20ecd1`.
Slurm job `3575` on `DAN-DESKTOP` compiled and ran both editions and both
schedules twice. Each schedule replayed identically, but the per-thread results
changed when the delayed sibling was reversed:

- 2017 and 2023, base: `A=0,5,7,3,2,6,1,4`, `B=10,14,13,9,8,11,12,15`
- 2017 and 2023, reversed: `A=2,6,5,1,0,3,4,7`, `B=8,13,15,11,10,14,9,12`

This is a candidate §18.14.2 gap. A follow-up adds `$urandom()` per-thread
controls to confirm the schedule change is isolated to `shuffle()`.
