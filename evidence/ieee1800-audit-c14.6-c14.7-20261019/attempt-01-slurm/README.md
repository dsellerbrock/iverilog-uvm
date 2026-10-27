# IEEE 1800 clauses 14.6 and 14.7 probes

Source is clean `origin/main` at `c31cbf1b52f1a39d5775f276e2340525a444a79e`. The probes exercise shared signals across clocking blocks, synchronization of two blocks on the same edge, per-instance clocking declarations and hierarchical access, and the forbidden task, package, and nested scopes. Positive tests must compile and run; negative tests must fail compilation. Both `-g2017` and `-g2023` are tested.

Slurm job 3163 ran on DAN-DESKTOP with 2 CPUs / 3 GiB and completed with exit code 0. The build took 3:03.64 and peaked at 1,662,908 KiB RSS. Icarus SHA-256: `c4aa6a50aa2875bb5e2b57089211512cc4a7fbac51bc1f48fd28b4c3e7e96208`; VVP SHA-256: `310a0343ea851fb8bd36e6002089eefdaaad1d942e42bc02f5862b8a27d67b12`. Each compile and simulation had a 120-second process timeout.

All ten expected outcomes passed: both positive cases ran to `PASSED` and all three negative cases were rejected under both editions. The audit lead classified §§14.6 and 14.7 as implemented for the tested subsets. The raw outputs/logs are in `results/` and `logs/`; `RAW-SHA256SUMS` matches `REMOTE-SHA256SUMS`, and `input/SHA256SUMS` matches the remote input check. The normative text is in IEEE 1800-2017 §§14.6–14.7 (p. 340) and IEEE 1800-2023 §§14.6–14.7 (p. 358).

The local-only source archive (`input/source.tar.gz`, 227,069,756 bytes) is excluded from the PR; SHA-256: `fb22d029cef3f9fa504bd5831a991b64755bcc449e2a80d75258a90096ba363c`.
