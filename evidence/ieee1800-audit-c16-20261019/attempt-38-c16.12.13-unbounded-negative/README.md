# IEEE 1800 §16.12.13 unbounded `eventually` rejection

- Slurm job: `3210` on `DAN-DESKTOP`, 2026-10-19 16:08 MDT; request 1 CPU, 1 GiB, 5 minutes. It completed in under one second; Slurm accounting is disabled, so peak RSS is unavailable.
- Toolchain: Icarus main `c31cbf1b52f1a39d5775f276e2340525a444a79e`; executable hashes are in `results/sha256.txt`.
- The direct concurrent assertion was compiled under `-g2017` and `-g2023`. Both return exit 1 with the required diagnostic: unbounded `eventually` is illegal and requires `s_eventually` or bounded `eventually [m:n]`.

The result confirms the rejection rule in IEEE 1800-2017/2023 §16.12.13. This clean rerun replaces the earlier negative control in attempt 37, which also emitted an unrelated named-property instantiation `sorry`.
