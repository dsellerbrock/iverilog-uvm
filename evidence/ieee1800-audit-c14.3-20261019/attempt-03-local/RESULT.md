# Attempt 03 — local build stopped before probes

- Source: `origin/main` at `c31cbf1b52f1a39d5775f276e2340525a444a79e`.
- Host: macOS; command used `~/codex-supervisor/localrun 600` with `make -j3`.
- Result: build failed in `vvp_z3.cc` because `z3.h` was not found. The log confirms the intern's diagnosis. No §14.3 probes ran.
- Resources: 181.01 seconds; peak RSS 1,367,457,792 bytes, as recorded in `results/localrun.log`.
- Next attempt uses DAN-DESKTOP's installed `/usr/include/z3.h` and a clean staged source snapshot.
