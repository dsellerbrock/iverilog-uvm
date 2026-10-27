# IEEE 1800 §11.3.4 two-state and four-state expression results

## Standards basis

IEEE 1800-2017/2023 §11.3.4 specifies that expression results are treated as
four-state values, with two-state results retained except where an operation
can produce X, such as division by zero. Assignment to a two-state integral
type coerces X to zero; assignment to a four-state integral type retains X.
Both editions include this division-by-zero distinction.

## Probe and result

[`p11_03_4_two_four_state_divzero.sv`](../../tests/1800_audit/c11/p11_03_4_two_four_state_divzero.sv)
reuses the standard's example shape: `int` and `integer` destinations receive
`n / zero + n`. `-g2017` and `-g2023` both compile and run, printing
`PASS two_state=0 four_state=xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx`.

The Mac ARM64 run used `~/codex-supervisor/localrun 60`; elapsed time was
0.33 s and peak RSS was 16,826,368 bytes. Each compiler and simulator
invocation had a 60-second timeout. Icarus was built from audit worktree HEAD
`27f53df2400f309a7b0d8e5ed5fc7ff9b0e0566e`, reporting 13.0 devel
`(27f53df24-dirty)`. SHA-256: iverilog
`4cca5dfcfded64ab5aa07255c3f0a3f5dbd8f56b6becdf0288c803f79d5a446c`;
VVP `2d5e711295134abc6a2553e9cb4215a33f2830e76f1dea5cd188cb991d88b704`.
Raw per-edition logs and compiled images are in `results/`.

## Issue dedupe

[`dedupe-results.txt`](dedupe-results.txt) preserves GitHub searches across
open and closed issues for §11.3.4 and two-state/four-state division by zero.
No matching issue was found. No issue was filed: both editions pass this
focused probe. The audit lead has not classified it because its helper still
reports the daily cap reached; matrix status is therefore `PROBED — LEAD
PENDING`.
