# IEEE 1800 §§16.12.9–16.12.13 temporal-property probes

- Slurm job: `3209` on `DAN-DESKTOP`, 2026-10-19 16:07 MDT; request 1 CPU, 1 GiB, 10 minutes. The job completed in under one second; each compile and simulation had a 120-second timeout. Slurm accounting is disabled, so peak RSS is unavailable.
- Toolchain: Icarus main `c31cbf1b52f1a39d5775f276e2340525a444a79e`; executable hashes are recorded in `results/sha256.txt`.
- Command: `iverilog -B <toolchain>/lib/ivl -g<2017|2023> -gassertions -s test -o <result>.vvp <probe>.sv`, then `vvp -n <result>.vvp`.

Results matched in both editions:

- **§16.12.9:** The standard-valid forms `sequence_expr #-# property_expr` and `sequence_expr #=# property_expr` are rejected with syntax errors; neither probe could run. The operators are distinct from `#-/#` (which is not the standard token).
- **§16.12.10:** Weak and strong `nexttime`, plus indexed weak and strong `nexttime[2]`, compiled and ran. One intentionally false unindexed case failed for each weak/strong form; both indexed checks passed.
- **§16.12.11:** Unbounded weak `always` and bounded weak `always [0:1]` each produced the expected one failure; bounded `s_always [0:1]` passed. Both simulations exited 0.
- **§16.12.12:** Weak/strong `until` and `until_with` passed their terminating cases; intentionally false weak/strong `until` cases each failed once. Both simulations exited 0.
- **§16.12.13:** `s_eventually`, bounded weak `eventually [1:2]`, and bounded strong `s_eventually [1:2]` compiled and ran exit 0. The unbounded weak `eventually` negative is rerun without an unrelated duplicate-property diagnostic in [attempt 38](../attempt-38-c16.12.13-unbounded-negative/README.md).

Clause references: IEEE 1800-2017 §§16.12.9–16.12.13; IEEE 1800-2023 §§16.12.9–16.12.13. The 2017 followed-by syntax is Syntax 16-18.
# Local-only build products

The compiled `results/p16_12_12_until-2017.vvp` (1,374,222 bytes, SHA-256 `d7729cf913f1e7037d0856522392cd31a2a65a94cba2d4eed208d869a3a95f26`) and `results/p16_12_12_until-2023.vvp` (1,374,222 bytes, SHA-256 `add5e5f26ab3ceacbd13a6ebf553c6661b2cb432417c92ddd434e6b0a95ea1f2`) are excluded from the PR. The source, results and logs remain preserved separately.
