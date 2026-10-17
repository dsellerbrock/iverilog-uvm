# Exact-head Slurm T0/T1 — job 1410

- Commit: `14a0326d21248842044b64a9633cf78a75bf03c2`
- Host: DAN-DESKTOP, Linux x86_64 / WSL2
- Allocation: 3 CPUs, 4 GiB; 2m12.06s build, 1,755,388 KiB peak RSS
- Result markers: issue reproducer, smoke, and T1 all `PASS`
- Toolchain hashes: see [`toolchain.sha256`](toolchain.sha256); source archive hash: [`source.sha256`](source.sha256)

T0 passed the eight registered issue cases in both legacy and strict JSON/VVP
runners. The smoke log records compiler/VVP 56/56, VPI 131/131, negative
152/152, and the remaining smoke checks. T1 passed the graph-selected fixed
multiclock-control lists 30/30 in each runner and implication-tree neighbors
1/1 legacy, 2/2 strict JSON/VVP.

The archived [`run-t0-t1.sbatch`](run-t0-t1.sbatch), list files, version
outputs, toolchain hashes, build timing and compressed logs capture the run.
Slurm accounting was unavailable after completion, so a scheduler exit code
and Slurm MaxRSS are not available; the script uses `set -e` and only writes
the three final `PASS` markers after their corresponding commands succeed.
