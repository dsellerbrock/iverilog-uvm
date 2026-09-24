# Bundled-BFM reset-copy replay (2026-09-24)

This completed `smoke_test_veer` replay used explicit `-gcommercial-unsafe`
and a hash-guarded copy of the **bundled Caliptra integration BFM** with its
initial `cptra_pwrgood` drive moved by `#0`. The pinned Caliptra and Adams
Bridge checkouts and all assertions remained unchanged. The exact compiler
profile and tool fingerprints are in [compile.command.json](compile.command.json).

[The case result](smoke_test_veer/result.json) and [summary](summary.json)
record a **diagnostic reset-overlay failure, 0/1 attempted with 51 unrun**.
Firmware and simulation exited zero; the testbench printed one pass marker
and no fail marker, and executed 633 retired instructions, 4,348 cycles, and
634 trace commits. All 19 startup assertion/error diagnostics seen on the
unchanged BFM disappeared. The run still emitted 17,844 `SVA ERROR` lines:
4,461 each from the KV debug, MLDSA private-key, public-key, and signature
helper functions. None of their corresponding outer assertion failure actions
appeared. The unchanged zero-error gate correctly rejects this run.

The [six-nanosecond passive trace](../caliptra-l0-timezero-passive-vpi-20260924/README.md)
ties the original 19 actions to state still unknown before the first clock.
This copied-reset result is separate from the pristine unsafe first-case
0/1 and from IEEE conformance. It establishes no L0 pass.
