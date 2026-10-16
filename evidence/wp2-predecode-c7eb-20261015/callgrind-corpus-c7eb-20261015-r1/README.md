# Callgrind corpus setup attempt

Pinned base: `c7ebca768c21c251d9c165c9aff0e363768030b1`.

Slurm job 1422 exited 127 before profiling because the script pointed to an
expired Valgrind extraction path. No benchmark ran and no measurement was
produced. Job 1423 used the retained Valgrind 3.26.0 extraction and completed
the full corpus; see [r2](../callgrind-corpus-c7eb-20261015-r2/README.md).
