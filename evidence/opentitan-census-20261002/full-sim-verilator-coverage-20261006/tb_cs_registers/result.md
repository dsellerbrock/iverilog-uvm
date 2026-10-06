# `tb_cs_registers` Verilator run

Status: **PASS with a build-local Verilator port overlay**.

The first standalone run used the upstream `inout` clock/reset declarations.
Generated C++ had no per-cycle DPI call sites, so the test never advanced its
register driver and ran for 3 h 14 min without `$finish`. It was stopped with
`SIGTERM` (exit 143) and is classified as incomplete, not a test failure.

A three-cycle repro with Verilator 5.050 confirmed that an `inout` top-level
clock emitted no DPI ticks, while changing it to `input` emitted all three.
Changing `clk_i` and `in_rst_ni` to `input` in the temporary source copy restored
the generated `env_tick`, `rst_tick`, `monitor_tick`, and `driver_tick` calls.
The upstream source was not modified; the minimal overlay is
[`verilator-port.patch`](verilator-port.patch), and hashes are in
[`source-overlay-manifest.json`](source-overlay-manifest.json).

The 1,000-cycle capped probe drove 94 transactions. The full run used
`--term-after-cycles=250000` as a safety cap and completed before reaching it:

- Exit status: `0`
- `$finish`: observed
- Register transactions: `10001`
- Executed cycles: `104892`
- Wall time: `0.041 s` (`2.56 million cycles/s`)
- Log: [`run-input-ports.log`](run-input-ports.log)

The capped probe's own `TEST PASSED` banner is not counted as a pass; only the
full run's normal `$finish` and 10,001 transactions establish this result.
