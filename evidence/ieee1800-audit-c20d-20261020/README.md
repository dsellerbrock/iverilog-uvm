# IEEE 1800 §20.8 math-function paired probe

## Standards basis

IEEE 1800-2017/2023 §§20.8.1–20.8.2 cover `$clog2` and mathematical system
functions. This probe samples power-of-two and adjacent `$clog2` values,
constant `$sqrt`, and real logarithmic, exponential, root, power, rounding,
trigonometric, inverse-trigonometric, `atan2`, `hypot`, and hyperbolic results.

## Result

All seven existing probes in `tests/1800_audit/c20/s/` compiled and ran in
both `-g2017` and `-g2023`. Every result was `pass=1 fail=0`.

The Mac ARM64 run used `~/codex-supervisor/localrun 120`; elapsed time was
2.67 s and peak RSS was 16,957,440 bytes. Each compile and simulator process
had a 60-second timeout. Icarus was built from audit worktree HEAD
`27f53df2400f309a7b0d8e5ed5fc7ff9b0e0566e`, reporting 13.0 devel
`(27f53df24-dirty)`. SHA-256: iverilog
`4cca5dfcfded64ab5aa07255c3f0a3f5dbd8f56b6becdf0288c803f79d5a446c`;
VVP `2d5e711295134abc6a2553e9cb4215a33f2830e76f1dea5cd188cb991d88b704`.
Per-edition logs and images are in `results/`; the localrun resource record is
`localrun.log`.

The matrix records this as a tested subset pending the audit lead's
classification. No new gap was found or filed by this probe.
