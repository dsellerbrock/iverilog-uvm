# Attempt 04 — Slurm T0/T1

- Source: `b172f88cb` (`agent/a3-m7-issue671-array-slice-20261019`).
- Host: DAN-DESKTOP; Slurm job 3149, 2 CPUs / 3 GiB.
- Build/install: passed; `make -j2` took 3:04.29 and peaked at 1,663,008 KiB RSS.
- Installed compiler SHA-256: `40059304546ba7a3f55027104d20354370209eae1fabf41cea66aba47f8150d8`.
- T0 legacy issue cases: passed both editions (`Total=2, Passed=2, Failed=0`).
- T0 JSON issue case: failed only on stdout golden comparison; expected output is empty, actual output is `PASSED`. No compile or runtime failure occurred.
- The script stopped at that JSON mismatch, so smoke and T1 did not run. No T0/T1 pass is claimed.
- Raw results and Slurm log were copied to `raw-slurm-3149/`; local hashes match the remote SHA-256 manifest.
- Next: after the required golden approval, add the one-line expected JSON output and rerun T0/T1 on the updated commit.
