# Job 1135 profiles

Pinned measurement base: `f9f8e0a79f230f38da6cbb4445994ad1075ad531`.
Candidate: `a5aad31659540d6a4c67bbaeffbeaa484b31f442`.

`reference.callgrind.gz` and `candidate.callgrind.gz` are the losslessly
compressed completed profiles; their uncompressed hashes are in
`profiles.SHA256SUMS`.
The original helper exited 1 after both VVP processes completed because it
treated any instruction-count difference as failure. The captured counts and
byte-identical output are valid; see `attempt-status.txt`. The exact helper
used is `callgrind-instruction-ab.executed.sh`; the current helper one level
up reports the count difference rather than enforcing equality.

The selected hot-path instruction counts match exactly in
`hot-path-counts.csv`. The full process count differs by 70 instructions; that
residual is outside the selected functions and is retained without a tolerance.
