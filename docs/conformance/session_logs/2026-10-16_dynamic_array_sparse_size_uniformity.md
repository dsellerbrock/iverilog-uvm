# Sparse dynamic-array size uniformity — 2026-10-16

## Requirement

IEEE 1800-2017 §18.5.10 and IEEE 1800-2023 §18.5.9 require the random values
to be uniformly distributed over legal value combinations. The corresponding
paragraphs use the same requirement in both editions. For a dynamic array,
the selected size and active element values together form the tested tuple.

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

This evidence covers the bounded one-dimensional direct-integral array path.
Nested/member arrays, queues, associative arrays, unsupported solver shapes,
and cases exceeding existing solver budgets remain outside this result; see
the dynamic-array uniformity entry in `../BLOCKERS.md`.
