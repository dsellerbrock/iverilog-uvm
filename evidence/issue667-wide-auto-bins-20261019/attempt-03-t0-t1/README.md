# #667 T0/T1 attempt 2 — harness fixture failure

Slurm job 3108 completed the build and install (3 CPUs, 3 GiB; build peak
1,669,928 KiB), then stopped at the legacy issue regressions because the
runner selects module `top` by default while the new test source named it
`test`. The source-level feature did not produce a compiler diagnostic in
this run; this is a test fixture setup error, not a feature test result.

The module was renamed `top`, and the JSON descriptors were aligned to
`-s top`. Against the candidate compiler installed by job 3108, both 2017 and
2023 focused compile/run checks passed (`PASSED`). Their exact logs, compiler
hashes and job status are in `remote-job-3108/`. A corrected full T0/T1 job is
job 3111; its evidence is recorded under attempt-04.
