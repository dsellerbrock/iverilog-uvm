# Wide sparse coupled legal-tuple sampling (#416) — 2026-10-16

## Standard and scope

IEEE 1800-2017 §18.5.10 and IEEE 1800-2023 §18.5.9 require uniform
distribution across legal value combinations. The fix adds exact reservoir
sampling for connected direct-scalar components that include variables wider
than 64 bits when their full legal tuple set has at most 1,024 members.
Components above that cardinality and unsupported soft, array, or member shapes
retain the existing fallback; the paired 1,025-tuple control checks legality,
not uniformity. Broader clause 18 conformance remains partial.

The paired positive test uses a 65-bit value and a one-bit mode. It has one
`mode=0,value=0` tuple and 256 `mode=1,value=1..256` tuples. With seed 416, the
baseline produced `mode=1` 20/32 times, below the test's 28/32 lower bound.
The test also checks contradictory constraints preserve the original value on
failure and that the 1,025-tuple boundary result is legal.

## Validation

Slurm job 1768 ran on DAN-DESKTOP (Ubuntu 26.04.1, GCC 15.2.0, Bison 3.8.2,
4 CPUs, 4 GiB requested) from base commit `7f508a8a3ab4f1a230d65abfa2543a12ca2f40a9`.
Build/install and the smoke set passed. Focused results were:

- T0 issue regressions: legacy 2/2, JSON 2/2.
- T1 randomization area: legacy 8/8, JSON 8/8.
- Smoke negative suite: 152/152.
- Overall job exit: 0; elapsed time: 8m45s.

The T1 lists include the existing global-uniformity tests, sparse coupled
tests, the new 2017/2023 wide positive/rollback/boundary tests, and adjacent
sampling-failure controls. Raw logs and final checksums are recorded in the
local supervisor evidence archive under
`evidence/a3-m6-issue416-20261016-03/` (job 1768). Slurm accounting did not
retain peak RSS; the requested memory limit was 4 GiB.

The full batch T2 gate, including its separately requested full JSON step, and
the PR's GitHub checks remain pending.
