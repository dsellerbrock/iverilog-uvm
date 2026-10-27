# T1 cached isolated-scalar hulls

Pinned measurement base: `10f3a0a2509d0852c2556cb6622fb0025121fb2d`.
Current PR head at measurement: `02acbc6ae38f6b4300a158bf20787e46121484ea`.
Candidate delta SHA-256: `e3b7376125b75518391e010e26a48bd094577d5cfbb67f4556906f1d37f3de76`.
The submitted delta adds one explanatory comment to preserve this measurement's
query-cap behavior; its SHA-256 is
`690decbc7ac17487666faa250dc8514a587b062f6abf96c8a4f7bcfe0079bc10`.
The measured patch is stored as `input/t1-hull-cache.patch.gz`; decompressing it
reproduces the measured delta SHA exactly. The batch script expands it before
applying it.

The exact-interval cache was rejected: the 1,000-call DVT trace had zero hits
because the sampler usually succeeds inside its hull-proposal stage. This
candidate caches only the min/max hull and the boundary-query count that the
normal sampler already computes. The key is the subject and isolated-factor
AST IDs inside a reused context. On a hit, the sampler still draws the same
full-domain and hull proposals in the same order; the saved query count keeps
the later exact-fallback cap unchanged.

The screen compares pinned base, PR #933, and the candidate on
`randomize_dv_txn` and `randomize_z3`, checks default outputs and eight seeds,
records hull-cache hits, and profiles each side with Callgrind on one CPU. Keep
only if the candidate cuts at least 10% of instructions on DVT and regresses
`randomize_z3` by no more than 2%, with all output comparisons identical.

Slurm job 3818 passed. The default output and eight-seed outputs for both
workloads matched the pinned base and current PR byte-for-byte. Candidate
Callgrind instructions were 44,754,551,050 vs 72,981,246,600 for DVT
(-38.68%, 1.630700x) and 5,782,607,074 vs 5,781,316,490 for `randomize_z3`
(+0.0223%, within the 2% limit). Relative to the pinned base, the candidate is
2.370211x on DVT and 2.252126x on `randomize_z3`.

The 1,000-call DVT perf-stat run recorded 874 hull-cache hits, 37,404 Z3 checks
and 157,544 model evaluations; the existing positive-count cache also hit 874
times. Callgrind ran on CPU 0 with one CPU pinned. Results and profile hashes
are in `artifacts/job-3818/results/`; raw Callgrind profiles remain in the
isolated Slurm run directory. The focused screen qualifies the change for the
full corpus and correctness gates, which are pending on the submitted source.
The 10x M5 target remains unmet.
