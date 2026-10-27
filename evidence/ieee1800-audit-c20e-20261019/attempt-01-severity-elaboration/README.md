# §20.10 severity and elaboration severity tasks

Clause crosswalk: 2017 §20.10–§20.11; 2023 §20.10–§20.10.1.

Date: 2026-10-20. Host: `MacBook-Air.local`, Darwin 27.0.0, arm64.

Probe sources are `tests/1800_audit/c20/r20_10_*.sv` and `r20_11_*.sv`; both `-g2017` and `-g2023` were tested. Command: `evidence/ieee1800-audit-c20e-20261019/attempt-01-severity-elaboration/run-probes.sh`. The script applies `~/codex-supervisor/localrun 10` independently to each compile and run, sequentially.

Toolchain: `/tmp/a3-t2-batch-2026-10-19-6-local-r6/local-install/bin/iverilog` SHA-256 `7ce507279ef15cb404b9ce70ba47902c4264daebffaf1b340bfb351adcc9c2b0`; `vvp` SHA-256 `e74cb1b690dc2ff07c928684df0df302d053bd94ff4a4a30bf8e10adb7da0b1d`.

Results in both editions:
- All four §20.10 run probes compiled and terminated with rc=1. `$fatal(0/1/2)` printed its message, time and scope, and suppressed the following `AFTER` statement; `$fatal(2)` did not print simulator statistics. In the combined severity probe, `$info`, `$warning`, and `$error` printed their formatted text, source line, time and scope; `$error` did not stop execution (`AFTER_ERROR_NOARG` printed), and `$fatal` then stopped before `AFTER_FATAL`.
- All four §20.11 examples were rejected during compilation, so no simulation ran. `$error` with a format argument returned rc=2, `$warning` with a format argument rc=1, `$fatal` rc=1, and generated `$info` with a format argument rc=3. The formatted `$error`, `$warning`, and `$info` cases report `sorry: Elaboration tasks currently only support a single string argument.` The `$fatal` elaboration message is printed and `SIM_RAN` is absent.

The script summary contains all outputs; each compile/run has an individual log. There are 24 localrun records; summed child real time is 0.53 seconds, maximum recorded RSS 5,193,728 bytes.
