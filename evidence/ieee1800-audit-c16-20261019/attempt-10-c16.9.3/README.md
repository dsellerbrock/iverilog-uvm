# IEEE 1800 §16.9.3 sampled-value probes — runner failure

Slurm job 3180 stopped before compiling any source. Bash exited at the
`run_positive` function's `local` declaration because `set -u` expanded the
`stem` initializer before the same declaration assigned `name` and `edition`.
This is an audit-runner defect, not simulator evidence. The unchanged probes
are rerun with a corrected runner in attempt 11.
