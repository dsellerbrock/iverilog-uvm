# Clause 6.6 follow-up controls 2 — results

Slurm job 3766 completed on DAN-DESKTOP in 3 seconds with scheduler state
`COMPLETED`, exit `0:0`. It ran each source with pinned Icarus
`cc25756d1`, `-B`, `-g2017` and `-g2023`, one CPU and 1 GiB. Each compile
and run had a 30-second timeout and `ulimit -f 262144` (the shell reported
262144 file-size blocks). `sacct` accounting is disabled; the captured
`scontrol` record confirms the final job state.

| Case | `-g2017` | `-g2023` |
|---|---|---|
| C1 struct variable drives net | The original net-declaration-assignment form failed with `Net n can not be of type <no_type>`. The lead's corrected separate declaration plus `assign` form also failed with the same diagnostic (job 3767). | Same in both forms |
| C2 continuous assignment to struct variable | Compile rc 153; `File size limit exceeded`; generated VVP reached 257M | Same diagnostic; VVP reached 256M |
| C3 `always_comb` struct pattern | Compile/run 0; prints `1 3` | Same |
| U1c real resolver | Compile/run 0; prints `3.5` | Same |
| U2c resolver alias | Compile/run 0; prints `3.5` | Same |
| U3c force/release | Compile/run 0; prints `forced 9.0` then `released 3.5` | Same |

The audit lead classified the local C1 net rejection as the same root cause
as #818; the scope comment is linked from `DEDUPE.md`. C2 is the new §6.5 /
§10.3 gap #922. Real-valued resolver, alias, and force/release support are
confirmed, while the struct-return resolver failure from job 3765 is the
separate §6.6.7 gap #923. Raw logs, status rows, resource limits, toolchain
and source hashes, and Slurm metadata are in `raw-slurm-3766/`.
After copying that evidence, staged source copies and generated VVP files
were removed from the Slurm run directory; logs and small result metadata
remain there. The run directory is 116 KiB and the host reports 674 GiB
available.
