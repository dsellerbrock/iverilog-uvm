# Sparse dynamic-array size uniformity — 2026-10-16

## Requirement

IEEE 1800-2017 §18.5.10 and IEEE 1800-2023 §18.5.9 require uniform
distribution over legal value combinations. For this non-iterative case, the
tested combinations are the selected size and active element values; there is
no `solve...before` constraint. Clause 18.4 describes resizing before element
randomization, but does not state a probability ordering. The explicit
size-first rules are for size constraints combined with foreach or array
reduction constraints: §18.5.8.1/.2 (2017), §18.5.7.1/.2 (2023). The tested
scope excludes those iterative cases and is based on the absence of a general
size-first probability rule.

## Reproducer

`ivtest/ivltests/sv_randomize_global_uniform.v` adds a paired-edition case with
`payload.size()` in `{1, 3}` and `payload[0] == 0` at size 3. There are two
legal size-one tuples and four legal size-three tuples. Across 600 draws, each
of the six bins must be between 60 and 140. The same test asks for the
contradictory size 2 and checks that failed randomization preserves an existing
one-element array. The existing suite also retains its 512/513 size boundary
case.

## Verification

Slurm job 1783 used base `7f508a8a3ab4f1a230d65abfa2543a12ca2f40a9` plus the
working-tree patch; the resulting source tree was
`da243451592f78d0679b221c72a77fe5476cf6ec`. On DAN-DESKTOP (Ubuntu 26.04.1,
GCC 15.2.0, Bison 3.8.2), T0 build/install and smoke passed; legacy
`sv_randomize_global_uniform` 2/2 and JSON 2/2 passed. T1 legacy
`regress-randomize-joint-dynamic-element-order-legacy.list` passed 10/10 and
the paired JSON list passed 10/10. All harness stages exited 0 and emitted
`T0_T1_PASS` after 11m10s (4 CPUs, 5 GiB requested).

The harness and checksummed logs are preserved at
`~/codex-supervisor/evidence/a3-m6-issue417-20261016-01/`; the remote log
manifest and local checksum verification are included there. The remote
1.3-GiB source/build copy was removed after verification.

## Boundary

This evidence covers the bounded one-dimensional direct-integral array path
without iterative constraints or `solve...before`. Nested/member arrays,
queues, associative arrays, unsupported solver shapes, iterative size-first
cases, and cases exceeding existing solver budgets remain outside this
result; see the dynamic-array uniformity entry in `../BLOCKERS.md`.
