# Pinned-base Slurm correctness gate

Job 2613 ran against `ca559fd97b19bd6a56cc10f0faf8583b4077975f` with the
combined WP6 patch. All five stages exited zero:

- VPI integer-conversion semantic comparison.
- `make check` and FPGA target install.
- Legacy ivtest: 7,477 total, 0 failed (7,472 passed, 2 not implemented,
  3 expected failures); VPI 133/133; negative tests 152/152; runtime
  invariants 15/15; JSON ivtest 4,718/4,718.
- Real-DPI UVM: 367 passed, 0 failed, 0 skipped.

The logs, environment, binary hashes, stage statuses, and submodule manifest
are in `full-gates-2613.tgz`.
