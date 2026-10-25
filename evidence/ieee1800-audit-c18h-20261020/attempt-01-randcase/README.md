# §18.16 randcase probe

Lead-directed probe of weighted branch selection, individual and all-zero weights, mixed-width expression weights, and weight-expression evaluation count (2017 §18.16 pp. 543–544 / 2023 §18.16). The 3:1:4 sample uses 800 calls and approximately four-standard-deviation bounds. Every compile/runtime process uses a 30-second timeout.

The Slurm script uses the pinned current-main Icarus toolchain. Open/closed issue dedupe is recorded before the run. No issue will be filed until the raw result is classified by the audit lead.

Attempt 1 setup note: Slurm job 3397 exited before compilation because the first staging command placed inputs at the run root rather than the input directory; no probe result was produced. Its startup log is preserved as logs/job-3397-staging-error.out. Attempt 2 uses a fresh run directory with the expected layout.
