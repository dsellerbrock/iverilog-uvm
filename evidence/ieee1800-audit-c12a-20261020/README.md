# IEEE 1800 §12.5.4 asymmetric `case inside` matching

## Standards basis

IEEE 1800-2017/2023 §§12.5.4 and 11.4.6 specify that `case inside` evaluates
the case expression as the left operand and each case item as the right
operand of asymmetric wildcard matching. X/Z/? in a case item can match an
expression bit; an X in the expression does not wildcard-match a known case
item. Both editions state this rule.

## Probe and result

[`p12_05_4_case_inside_asymmetry.sv`](../../tests/1800_audit/c12/p12_05_4_case_inside_asymmetry.sv)
checks that a `?` in the item matches X and Z in the expression, while X in
the expression does not match a known item bit. `-g2017` and `-g2023` both
compile and run, printing `PASS asymmetric case-inside wildcard matching`.

The Mac ARM64 run used `~/codex-supervisor/localrun 60`; elapsed time was
0.35 s and peak RSS was 16,941,056 bytes. Each compiler and simulator
invocation had a 60-second timeout. Icarus was built from audit worktree HEAD
`27f53df2400f309a7b0d8e5ed5fc7ff9b0e0566e`, reporting 13.0 devel
`(27f53df24-dirty)`. SHA-256: iverilog
`4cca5dfcfded64ab5aa07255c3f0a3f5dbd8f56b6becdf0288c803f79d5a446c`;
VVP `2d5e711295134abc6a2553e9cb4215a33f2830e76f1dea5cd188cb991d88b704`.
Raw per-edition logs and compiled images are in `results/`.

## Issue dedupe

[`dedupe-results.txt`](dedupe-results.txt) preserves open-and-closed issue
searches for §12.5.4 and case-inside asymmetric wildcard behavior. No matching
issue was found. Both editions pass this probe, so no issue was filed. The
lead has not classified the row because the helper still reports its daily
cap reached; matrix status is `PROBED — LEAD PENDING`.
