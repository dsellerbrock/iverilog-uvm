# IEEE 1800 §20.4 timescale tasks and functions

## Standards basis

IEEE 1800-2017 §20.4 defines `$printtimescale` and `$timeformat`. IEEE
1800-2023 §20.4 retains those tasks and adds `$timeunit` and
`$timeprecision` system functions. Under 2023, these report the current
scope's unit/precision without an argument, or the named design element's
values with a hierarchical argument; `$unit` and `$root` are also defined.

## Probe and result

The existing
[`sv_timeunit_functions.svh`](../../ivtest/ivltests/sv_timeunit_functions.svh)
regression exercises current scope, module, child, package, compilation-unit,
and root results, plus a non-hierarchical argument rejection. Under
`-g2023`, it compiles and runs with `PASSED`; the invalid argument is rejected.
Under `-g2017`, use of these 2023-only functions is rejected with the expected
edition diagnostic. Existing paired tests for `$printtimescale` and
`$timeformat` are recorded in
[`the earlier §20.2–§20.5 evidence`](../ieee1800-audit-c20a-20261019/attempt-06-clean-run/).

The Mac ARM64 run used `~/codex-supervisor/localrun 60`; elapsed time was
0.41 s and peak RSS was 16,908,288 bytes. Each compile/run command had a
60-second timeout. Icarus was built from audit worktree HEAD
`27f53df2400f309a7b0d8e5ed5fc7ff9b0e0566e`, reporting 13.0 devel
`(27f53df24-dirty)`. SHA-256: iverilog
`4cca5dfcfded64ab5aa07255c3f0a3f5dbd8f56b6becdf0288c803f79d5a446c`;
VVP `2d5e711295134abc6a2553e9cb4215a33f2830e76f1dea5cd188cb991d88b704`.
Logs and compiled images are in `results/`; localrun output is
`localrun.log`.

## Issue dedupe

[`dedupe-results.txt`](dedupe-results.txt) preserves open-and-closed searches
for §20.4 and the two 2023 functions. No matching issue was found. The tested
edition split conforms; the lead has not classified the full clause, so the
matrix status remains `PROBED — LEAD PENDING`.
