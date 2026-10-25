# §18.5.3 `default :/` bounded follow-up

- IEEE 1800-2023 §18.5.3, pp. 531–533. The first 8000-sample run in Slurm job 3437 compiled cleanly but timed out after 30 seconds without output.
- This lead-directed follow-up uses 3000 samples, with expected counts `in=2250 ±119`, `out=750 ±119`, and `distinct_out >200`.
- Source checkout: branch `m7-1800-audit-c08`, commit `27f53df24`, dirty before this probe. Updated source and timeout harness are staged under `input/` and SHA256 recorded below.
- Slurm plan: DAN-DESKTOP, Icarus 13.0-devel `cc25756d1`, 1 CPU / 1 GiB / 3 minutes. Compiler and runtime each have a 30-second process-group timeout; runtime is wrapped in `/usr/bin/time -p`.
- Dedupe output from the first paired-edition run is copied in `dedupe-open-closed.txt`; if this E4 probe reveals a gap, run a fresh exact open+closed dedupe before any issue is filed.
- Slurm job 3438 ran 2026-10-20 15:12:03–15:12:20 UTC (17 s total), with compile rc=0 and run rc=0. The run output was `E4 in=2255 out=745 distinct_out=243` and `E4 t=0`; `/usr/bin/time -p` reported 17.71 s real, 17.52 s user, 0.17 s system. This is within the expected count windows and supports the 2023 `default :/` semantics.
- Raw compile/run logs, result table, version, hashes, and timestamps are in `remote-results/`. Slurm accounting is disabled, so peak RSS was unavailable. The tool binary SHA256 values were `1088dd266d4715d5a99d4eb5f7ae7a128449744927bae1971b37278872613593` (iverilog) and `e66837952db8927f4ef69007b4290c07e23f30f9258facae416da98c95715bbb` (vvp).
