# Attempt 01 result — staging error

Slurm job 3496 did not compile or run any probe. The archive was extracted at
the run-directory root while `run.sbatch` expects it below `input/`; the
preflight `sha256sum` therefore stopped the script before test execution.
This is a harness setup failure and provides no simulator evidence.

The job log and initial metadata are preserved in
`results-3496-harness-failure.tar.gz`. The run directory was removed after
copying those records. Attempt 02 extracts the same frozen input archive under
`input/` and runs in a fresh Slurm directory.
