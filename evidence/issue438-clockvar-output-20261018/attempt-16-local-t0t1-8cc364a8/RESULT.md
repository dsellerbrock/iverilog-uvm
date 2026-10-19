# #669 exact-head local T0/T1 — 2026-10-19

## Source and host

- PR #669 source commit: `8cc364a884554c0080ca9ec80d52380d926f0cd4`.
- Source archive SHA-256: `45422e026a71509727f59269272bb0b917f66c1acc80a956b64728d6ce396130`.
- Host: `MacBook-Air.local` (macOS), localrun budget 3,000 seconds, `make -j3`.
- Localrun command: `~/codex-supervisor/localrun 3000 /tmp/a3-438-t0t1-local-retry.sh`.
- Exit: 0. Wall time: 196.07 seconds. Peak RSS: 112,001,024 bytes.
- Icarus SHA-256: `2969d88d66fc06aa843106f7c195c125d417022e284fb3c3a28b73dabd956752`.
- VVP SHA-256: `d51a01c63894946b8208fdfd23ee5b20fd7e9846833f4f99daa74ca0992643bb`.
- Version: Icarus Verilog 13.0 (devel); see `results/versions.txt`.

## Results

- Build and install: passed.
- T0 issue regressions: legacy 11/11; JSON/VVP 12/12.
- T0 smoke: VVP 56/56, VPI 133/133, negative diagnostics 152/152; all additional malformed-input and runtime invariant checks passed.
- T1 graph-selected clocking focus: legacy 49/49; JSON/VVP 55/55.
- All JSON cases ran individually through `vvp_reg.py` with process-group timeouts.

The build used Homebrew `libffi`/Z3 include paths and the Z3 library path. The smoke runner expects `source/local-install`; that path was linked to the same successfully built install prefix for this local run. The first smoke attempt failed only because that expected path was absent; the corrected run above passed all T0/T1 checks.

Full logs, per-case JSON statuses, test lists, toolchain hashes, versions, source hash, and the exact run script are stored alongside this result.
