# IEEE 1800 §20.3 simulation-time system functions

## Standards basis

IEEE 1800-2017/2023 §§20.3.1–20.3.3 define `$time`, `$stime`, and
`$realtime`. The returned time is scaled to the time unit of the scope where
the system function is called; `$realtime` preserves the real-valued result.

## Probe and result

[`p20_03_scaled_time_functions.sv`](../../tests/1800_audit/c20/p20_03_scaled_time_functions.sv)
calls all three functions in 1 ns and 1 ps scopes at the same 1 ns simulation
time. `-g2017` and `-g2023` both compile and run, printing `time=1 realtime=1.000
stime=1` in the ns scope and `time=1000 realtime=1000.000 stime=1000` in the
ps scope.

The final Mac ARM64 run used `~/codex-supervisor/localrun 60`; elapsed time
was 0.40 s and peak RSS was 16,941,056 bytes. Each compiler and simulator
invocation had a 60-second timeout. Icarus was built from audit worktree HEAD
`27f53df2400f309a7b0d8e5ed5fc7ff9b0e0566e`, reporting 13.0 devel
`(27f53df24-dirty)`. SHA-256: iverilog
`4cca5dfcfded64ab5aa07255c3f0a3f5dbd8f56b6becdf0288c803f79d5a446c`;
VVP `2d5e711295134abc6a2553e9cb4215a33f2830e76f1dea5cd188cb991d88b704`.
Raw edition logs, compiled images, and localrun output are in `results/` and
`localrun.log`. The initial probe-source error (case inequality applied to a
real) is preserved under `attempt-01/`; it was corrected before the final
paired run.

## Issue dedupe

[`dedupe-results.txt`](dedupe-results.txt) preserves open-and-closed searches
for §20.3 time functions and scope scaling. No matching issue was found.
The lead has not classified this tested subset because the helper still
reports its daily cap reached; matrix status is `PROBED — LEAD PENDING`.
