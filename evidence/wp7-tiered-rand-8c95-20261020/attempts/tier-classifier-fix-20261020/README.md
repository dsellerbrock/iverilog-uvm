# WP7 classifier correction attempt (job 3390)

Measurement base: `8c95b5cc10fc83d15b47e0364d2d7b4a2e12cac1`.
Candidate parent: `fdb1fd05c26536c79b40bfa30c0c0988c1b768ae` plus
`input/classifier.patch` (SHA-256 `f15da682278c1866f8fc4e0c25440a37d8c65fae650a99c58d98c9624eb78e6a`).

Both builds completed, and the focused `test_perf_stats.sh` assertions passed.
The job then exited 2 because its histogram command pointed to
`benchmarks/sim-hotspots/collect_tier_hist.py`; the collector is an evidence
input, not a tracked source file. The failure and logs are retained in
`results/`. Job 3394 reran the focused assertions and collection successfully
using the same pinned source/build artifacts; see the sibling recheck attempt.
