# Attempt 05 — Slurm §14.3 probes

- Source: `origin/main` at `c31cbf1b52f1a39d5775f276e2340525a444a79e`, plus the staged §14.3 probe files.
- Slurm job 3152 built and installed successfully on DAN-DESKTOP with 2 CPUs / 3 GiB; build time 3:04.62 and peak RSS 1,663,012 KiB.
- Icarus SHA-256: `8dc2e450d92f37131ed785ce69287e22b7ba0af6df55f88828b1469aac01928f`; VVP SHA-256: `6cd0106fbf67728cae430968e56376936d1fcc8d366fd361edae87fd564a94ce`.
- Of 14 compile/run outcomes, 8 matched expectations and 6 did not:
  - Expected pass: `p14_03_clocking_decl -g2023`, `p14_03_clocking_decl_2017` under both editions, and `p14_03_zero_output_skew -g2023` all passed.
  - Expected pass but rejected: `p14_03_end_label` under both editions. Its `endclocking : cb` form is allowed by the §14.3 grammar in both 1800-2017 and 1800-2023.
  - Expected rejection but accepted: the `#0` output-skew cases under `-g2017`; §14.3 requires positive integer skew in 2017, while 2023 permits non-negative skew.
  - Correctly rejected: writes to an input clockvar and an unnamed non-default clocking block, under both editions.
  - Expected rejection but accepted: reads of an output clockvar under both editions; §14.3 makes this illegal in both standards.
- Full compiler/runtime logs and hash manifests are under `results/` and `logs/`. Local hashes match the remote manifest.
- These are raw probe outcomes pending the persistent audit lead's classification and issue filing.
