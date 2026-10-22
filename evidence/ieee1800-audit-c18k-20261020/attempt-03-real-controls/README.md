# IEEE 1800-2023 real `inside` and uniqueness controls

- Standard: IEEE 1800-2023 §18.5.4 (p. 534); scalar `rand real` support is covered by §18.4. This follow-up separates real-set membership, interval constraints, real `unique`, and explicit inequality.
- The lead's R1/R1P probe is retained, with C0–C3 added as controls. Open+closed dedupe queries are recorded in `dedupe-open-closed.txt`.
- Slurm job 3458 ran on DAN-DESKTOP with 1 CPU / 1 GiB at 15:29:26Z. Each compiler and runtime process had a 30-second process-group timeout. Version, hashes, result table and full output are in `remote-results/`; peak RSS is unavailable because Slurm accounting is disabled.

Expected: R1 `ok=100 bad=0`, R1P `rc=0`, and C0–C3 each `ok=100 bad=0`.
