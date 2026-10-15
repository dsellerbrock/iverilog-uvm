# Callgrind A/B: job 1182

Campaign-pinned base: `f9f8e0a79f230f38da6cbb4445994ad1075ad531`.
Measurement base: `7f35ca38c86723ab40e6ebfe9fd77259827e23f9`.
Candidate source: `1174ea06ac5e3a926b1fa1c1bd3449a396507272`.

One shared benchmark program ran against the reference and stats-off candidate
runtime. Both completed with byte-identical stdout/stderr. Callgrind counted
94,600,024,298 reference instructions and 94,600,024,572 candidate
instructions: +274 (+0.000000290%). The eight selected function-node counts
match exactly; see [`hot-path-counts.csv`](hot-path-counts.csv). The values
were extracted with [`extract-hot-path-counts.py`](../extract-hot-path-counts.py).

The gzip profile files pass integrity checks, and their decompressed SHA256
values match the hashes captured before compression in
[`profiles.SHA256SUMS`](results/profiles.SHA256SUMS). The profiling script
completed both runs and wrote a PASS result. Slurm returned exit code 1 only
afterward: its final checksum glob included `results/work`, which is a
directory. [`submitted.sbatch`](submitted.sbatch) preserves that exact
submission; the neighboring script was corrected to hash regular files only.
