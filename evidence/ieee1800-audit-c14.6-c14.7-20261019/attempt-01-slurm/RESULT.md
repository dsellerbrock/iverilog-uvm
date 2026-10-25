# Clauses 14.6 and 14.7 raw probe results — Slurm job 3163

- Clean source: `origin/main` at `c31cbf1b52f1a39d5775f276e2340525a444a79e`.
- Standard references: IEEE 1800-2017 §§14.6–14.7 (p. 340); IEEE 1800-2023 §§14.6–14.7 (p. 358).
- Host: DAN-DESKTOP; 2 CPUs / 3 GiB requested; job completed with exit code 0 in 00:03:09.
- Build: `make -j2`, wall time 3:03.64, peak RSS 1,662,908 KiB.
- Icarus SHA-256: `c4aa6a50aa2875bb5e2b57089211512cc4a7fbac51bc1f48fd28b4c3e7e96208`; VVP SHA-256: `310a0343ea851fb8bd36e6002089eefdaaad1d942e42bc02f5862b8a27d67b12`.
- All 10 expected outcomes passed. Local result hashes exactly match the remote hashes; source/probe input hashes also match.
- After recording the results, removed only this run's remote `source/`, `install/`, and `input/` trees. Freed 1,629,962,959 bytes (1.63 GB / 1.52 GiB); remote `results/` and `logs/` remain.

## Results

- `p14_06_shared_signals`: PASS under `-g2017` and `-g2023`. Two clocking blocks using the same positive edge both sampled the shared input; a third block using the negative edge sampled it after one block drove the shared output.
- `p14_07_instance_scope`: PASS under both editions. Two instances of a module with a clocking block independently sampled and drove their own signals; the test accessed the block through a hierarchical instance handle.
- `n14_07_clocking_in_task`, `n14_07_clocking_in_package`, and `n14_07_nested_clocking`: each failed compilation with syntax/error diagnostics under both editions.

The audit lead classified §§14.6 and 14.7 as implemented for the tested subsets. Unprobed scope cases remain listed in the status matrix.
