# §18.14.2 randsequence thread-stability probe

IEEE 1800-2017/2023 §18.14.2 says random values selecting `randsequence`
branches are independent of thread execution order. This probe seeds one parent
process, then runs two sibling processes that each make sixteen equal-choice
`randsequence` selections. The paired builds reverse which sibling is delayed;
`$urandom()` in each sibling is a process-seeding control. Both editions and
each schedule are repeated with a fixed seed.

Probe SHA-256: `8200f706bcd785d0a73190ea2615a38ec184a97d773553cda23d24d88cbbfe22`.
Slurm job `3578` on `DAN-DESKTOP` compiled and ran both editions and both
schedules twice; every compile, run, and replay control passed. Reversing which
sibling was delayed preserved the same values in both editions:
`A_u=4156023367`, `B_u=2045998359`, `A_rs=0122110222220001`, and
`B_rs=2102202122120201`. Raw outputs and result are retained under `logs/`.
