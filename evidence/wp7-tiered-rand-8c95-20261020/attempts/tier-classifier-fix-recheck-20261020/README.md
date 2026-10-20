# WP7 classifier recheck (job 3394)

Measurement base: `8c95b5cc10fc83d15b47e0364d2d7b4a2e12cac1`.
Candidate source parent: `fdb1fd05c26536c79b40bfa30c0c0988c1b768ae` plus
`input/classifier.patch` (SHA-256 `f15da682278c1866f8fc4e0c25440a37d8c65fae650a99c58d98c9624eb78e6a`).
The job reused the immutable reference and stats builds from job 3390 and ran
both the focused classifier assertions and histogram collector successfully
(exit 0). Its submitted input manifest is `input/SHA256SUMS`; post-submission
provenance files have a separate checksum list.

The corrected histogram is `results/histogram.json`. It reclassifies the
400-call `randomize_dv_txn` workload from T3-eligible to T4 because the IR
contains `dist`. The one-call solve-before fixture was separately asserted as
T4 by `test_perf_stats.sh`; it is a classifier fixture, not part of the corpus
histogram. The 18-workload runtime measurements are unaffected because this
correction is behind `VVP_PERF_STATS`.

The result bundle and its remote file checksums are kept alongside the
unpacked histogram and logs. The initial job 3390 failure remains preserved in
the sibling attempt directory.
