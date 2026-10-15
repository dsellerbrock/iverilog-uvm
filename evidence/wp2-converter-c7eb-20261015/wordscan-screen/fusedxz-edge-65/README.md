# Fused converter partial-word edge check

Pinned measurement base: `c7ebca768c21c251d9c165c9aff0e363768030b1`.

This version adds signed negative and Z-in-index cases at 65 bits. The Z at
bit 64 exercises a one-bit tail word after a full 64-bit word; `$display`
prints the regression runner's required exact `PASSED` line. Job 1396 checked
the prior 128-bit and narrow-index cases; this job validates the added 65-bit
tail cases.

The candidate patch SHA-256 is
`0306764c76587f0ac71c30fe05bf7c0f132e8911868bf8121398b347c7acee6f`.
The source SHA-256 is
`6d3a576660bc487640e02cae4f18028c0d716d17ef7f312fe19c8dd6dbcbbd90`; the
script SHA-256 is
`3c6f73ddc0c79d172a2383bf96d91ec7c5af9781cfae3ee7e889c645aec465a3`.

Slurm job 1405 completed with exit 0 using one CPU and 2 GiB. Reference and
candidate stdout and stderr are byte-identical, and both print exactly
`PASSED`. The checked-in `results-job1405/` keeps those streams, source
provenance, checksums, and the exit marker; compiled VVP files and compiler
logs remain in the local evidence archive.
