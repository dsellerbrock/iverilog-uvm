# Attempt 05 — Slurm T0/T1 harness correction

- Source commit: `b172f88cba48dd6b888df9cd5cbcafeb2b0856cc`, with the recorded reproducer edits in `input/working-tree.patch` and the approved JSON stdout golden in the source snapshot.
- Host: DAN-DESKTOP; Slurm job 3227, 2 CPUs / 3 GiB.
- Build/install passed. Installed `iverilog` SHA-256: `e14b4b0690b724ea8f3efe7193cb85b2b93d5ca282f460875680a6b06bf29dae`; `vvp`: `7d625c82be23b354156d5377d3af973f973a373a1ade07f8c62dc3f8302b588e`.
- T0 issue reproducer passed both legacy editions and both JSON editions; the JSON stdout matched `PASSED`.
- Smoke started and exercised multiple cases, then stopped because the runner expected `source/local-install/bin/iverilog` and `iverilog-vpi`, while this harness installed into `run_dir/install`. This is a harness path error, not a simulator test failure.
- T1 did not run. This attempt does not pass T0/T1; retry with the install prefix aligned to the smoke runner.
- Remote result and log hashes were copied and verified in `raw-slurm-3227/`.
