# §20.10 runtime and elaboration severity controls

Clause crosswalk: 2017 §20.10–§20.11; 2023 §20.10–§20.10.1.

Date: 2026-10-20. Host: `MacBook-Air.local`, Darwin 27.0.0, arm64.

Ran the five controls from the audit lead in both `-g2017` and `-g2023`. Command: `evidence/ieee1800-audit-c20e-20261019/attempt-02-controls/run-probes.sh`. Each compile and run used `~/codex-supervisor/localrun 10`, sequentially.

Toolchain: `/tmp/a3-t2-batch-2026-10-19-6-local-r6/local-install/bin/iverilog` SHA-256 `7ce507279ef15cb404b9ce70ba47902c4264daebffaf1b340bfb351adcc9c2b0`; `vvp` SHA-256 `e74cb1b690dc2ff07c928684df0df302d053bd94ff4a4a30bf8e10adb7da0b1d`.

Results, same in both editions:
- `r20_11_c1_single`: compile/run rc=0; one-argument `$warning` and `$info` include file, line and scope, then `SIM_RAN`.
- `r20_11_c2_error`: compile rc=1; emits `ERROR: ... Parameter N invalid`, `During elaboration Scope: genblk1`; no `SIM_RAN`.
- `r20_11_c3_gen`: compile/run rc=0; three `$info` messages print and then `SIM_RAN`, but reported scopes are `L[0]`, `L[1]`, `L[2]` (without the top module `m`).
- `r20_11_c4_noarg`: compile rc=1 due to `$error`; all three no-argument `$error`, `$warning`, `$info` diagnostics print with scope `m`; no `SIM_RAN`.
- `r20_10_c5_scope`: compile/run rc=0; runtime `$info` reports full scopes `top.G.u2` and `top.u1`.

There were 10 compile invocations (6 rc=0, 4 rc=1) and 6 runs (all rc=0). The 16 localrun records sum to 0.37 seconds of process real time; maximum recorded RSS was 5,292,032 bytes. All raw output is in `summary.log` and individual logs.
