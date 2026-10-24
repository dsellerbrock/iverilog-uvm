# IEEE 1800 §16.11 sequence match subroutines

This run also repeats the §16.10 increment match-item probe using a local variable assigned before `count++`, as required by §16.10. The §16.11 probes isolate each subroutine call to one match item so they do not depend on multiple-item parsing, which is already recorded as a §16.10 gap.

- Slurm job: `3200` on `DAN-DESKTOP`, 2026-10-19 15:47 MDT; request was 1 CPU, 1 GiB, 10 minutes. Start and finish are recorded in the same second; the remote run directory was removed after copying results.
- Toolchain: Icarus from main `c31cbf1b52f1a39d5775f276e2340525a444a79e`; hashes are in `results/sha256.txt`.
- The corrected local-variable `count++` probe fails syntax at the increment item in both editions. The combined §16.11 probe fails at the nonzero-argument call; this prevents using that file to classify its earlier zero-argument calls. The empty-match attachment probe is rejected at parse time in both editions, though the parser reports syntax error rather than identifying the empty-match rule. No probe ran at runtime.
- `p16_11_subroutine_calls.sv` was intentionally bundled only as an exploratory first attempt. Isolated §16.11 runtime evidence follows in [attempt 30](../attempt-30-c16.11-isolated/README.md).
