# Slurm job 1454 setup failure

Pinned base: `c7ebca768c21c251d9c165c9aff0e363768030b1`.
Candidate: `4f4ec93c86ce6d767ec4639d22213ef7dc05cfc9`.

Both source builds and installs completed. The runner stopped before any tests
because its binary-hash list expected `ivl` under `bin/`; this install places
it under `lib/ivl/`. This is a harness path error, not a test result. The fresh
r2 job corrects the location and uses a separate Slurm run directory.
