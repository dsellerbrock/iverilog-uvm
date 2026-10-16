# Pinned predecode full-gate setup attempt

Pinned base: `c7ebca768c21c251d9c165c9aff0e363768030b1`.
Candidate: `4f4ec93c86ce6d767ec4639d22213ef7dc05cfc9`.

Slurm job 1454 built and installed both revisions, then exited before tests
because its binary-hash command looked for `ivl` under `bin/`. The install
places it under `lib/ivl/`. No gate ran in this attempt. The corrected script
was submitted in a fresh run directory and passed as job 1457; see
[full-gates r2](../full-gates-c7eb-20261015-r2/README.md).

The source commits and archive hashes are recorded in `input/source-manifest.txt`.
The submitted runner is `run-predecode-full-gates.sbatch`; exact Slurm logs and
the failure state are retained under `attempt-1454-setup-failure/`.
