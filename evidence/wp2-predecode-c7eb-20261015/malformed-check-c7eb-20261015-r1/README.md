# Malformed-metadata smoke-test setup attempt

Pinned base: `c7ebca768c21c251d9c165c9aff0e363768030b1`.

Slurm job 1448 exited 1 before compiling or running the test: its staged
source path did not contain the overlaid regression source. This is a harness
setup failure, not a candidate result. The corrected fresh run is
[malformed check r2](../malformed-check-c7eb-20261015-r2/README.md).
