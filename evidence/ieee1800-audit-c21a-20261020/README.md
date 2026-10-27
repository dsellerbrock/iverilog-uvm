# IEEE 1800 §21.5.2 writing two-state arrays

## Standards basis

IEEE 1800-2017/2023 §21.5.2 permits `$writememb` and `$writememh` to write
unpacked arrays of two-state types, including `int` and enumerated types; enum
records use the enumerated values.

## Probe and result

[`p21_05_2_write_2state.sv`](../../tests/1800_audit/c21/p21_05_2_write_2state.sv)
writes a two-element `int` array to binary and an enum with explicit values
`A` and `5` to hex. `-g2017` and `-g2023` both compile and run. A post-run
check confirms the exact binary records and enum records `a`, `5` in order.

The Mac ARM64 run used `~/codex-supervisor/localrun 60`; elapsed time was
0.47 s and peak RSS was 16,891,904 bytes. Each compile and simulator
invocation had a 60-second timeout. Icarus was built from audit worktree HEAD
`27f53df2400f309a7b0d8e5ed5fc7ff9b0e0566e`, reporting 13.0 devel
`(27f53df24-dirty)`. SHA-256: iverilog
`4cca5dfcfded64ab5aa07255c3f0a3f5dbd8f56b6becdf0288c803f79d5a446c`;
VVP `2d5e711295134abc6a2553e9cb4215a33f2830e76f1dea5cd188cb991d88b704`.
Edition logs, output files, compiled images, and the localrun record are in
`results/` and `localrun.log`.

## Issue dedupe

[`dedupe-results.txt`](dedupe-results.txt) preserves open-and-closed searches
for §21.5.2 and two-state array/enum memory writes. No matching issue was
found. Both editions pass; no gap was filed. The lead has not classified the
clause because the helper reports its daily cap reached, so the matrix row is
`PROBED — LEAD PENDING`.
