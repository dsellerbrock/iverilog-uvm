# WP0 pinned-base instruction-count A/B

## Source revisions

| Role | Revision |
| --- | --- |
| Pinned measurement base | `f9f8e0a79f230f38da6cbb4445994ad1075ad531` |
| WP0 candidate | `a5aad31659540d6a4c67bbaeffbeaa484b31f442` |

The candidate stats-off compiler built one shared `behav.vvp` program. That
program ran under the reference VVP and the candidate VVP with the same seed.
Callgrind 3.26.0 counted Ir while `IVL_PERF_STATS=1` was set for both runs.

| Build | Callgrind Ir |
| --- | ---: |
| Reference VVP | 94,558,243,526 |
| Stats-off candidate VVP | 94,558,243,596 |
| Candidate minus reference | +70 (+0.000000074%) |

Stdout and stderr were byte-identical. The stats-off `config.h` leaves
`VVP_PERF_STATS` undefined, and `nm` found no `vvp_perf_stats_*` symbols in
the candidate VVP. The selected hot-path functions match instruction for
instruction; see [`hot-path-counts.csv`](job1135/hot-path-counts.csv). The
70-instruction whole-program difference is also recorded. It is outside those
selected functions and is not attributed to a performance-counter hook.

Job 1135 completed both profiles and the output comparisons, then exited 1
because the original helper incorrectly required exact instruction-count
equality. Its raw profiles and the exact helper used are preserved under
[`job1135`](job1135/). The current helper reports the count delta instead of
rejecting a measured difference; the benchmark was not rerun. Job 1133 is
preserved as a setup failure: the private Valgrind tool path was not exported
for its version check. Job 1135 exported the path and produced the profiles.

See [`job1135/attempt-status.txt`](job1135/attempt-status.txt) for hashes,
package checksums, and the full measurement record. Both jobs used pinned base
`f9f8e0a79f230f38da6cbb4445994ad1075ad531`.
