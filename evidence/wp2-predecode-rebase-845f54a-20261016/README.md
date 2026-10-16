# Post-rebase predecode instruction screen

The campaign pin remains `c7ebca768c21c251d9c165c9aff0e363768030b1`.
The single pre-merge rebase moved the candidate onto
`845f54a5724c4d2af13dde40eca6d290c80c41d9`; the runtime/build-path diff from
the pin to that main head changed 12 `vvp/` files (491 insertions, 33
deletions; see [`path-diff.txt`](path-diff.txt). This required the one
deliberate new-base measurement. Do not rebase again.

Slurm job 1496 rebuilt the reference from base `845f54a` and overlaid the
candidate source from commit `5579876e005c8406396f97ca8e051e5460846eae`.
It used 2 CPUs and 8 GiB. The fixed Caliptra
`smoke_test_dma_aes_gcm_short_1_dword` Callgrind window ran from mcycle 100 to
200:

| Variant | Instructions | Change |
| --- | ---: | ---: |
| Reference | 183,325,396,223 | — |
| Predecode + `setarray` | 164,442,681,700 | −10.300108% |

The instruction gate is cleared. Generated firmware inputs and visible
simulation output through the bounded window matched. The profile runner
reports `passed=false`, `sim_exit=0`, and no testcase pass/fail markers because
the measurement VPI plugin intentionally calls `vpiFinish` at mcycle 200. This
is a bounded instruction screen, not a complete Caliptra firmware pass. The
mutation self-check inverted the new 4-state regression assertion and VVP
rejected it with exit status 1. The summary files are
[`screen.txt`](run-1496/results/screen.txt),
[`instructions.csv`](run-1496/results/instructions.csv), and
[`mutation-check.txt`](run-1496/results/mutation-check.txt).

`input/` contains the reference source archive, source overlay, deterministic
ECC input, measurement VPI source, source manifest, and input checksums.
`run-1496/` contains the Slurm logs, reference/candidate Callgrind profiles,
runner summaries, binary/input hashes, and the screen result. The candidate's
full correctness gates and exact-head cross-platform workflow remain separate
required checks. The campaign status and supporting wall-time table are in
[`PERFORMANCE_PLAN.md`](../../docs/performance/PERFORMANCE_PLAN.md).
