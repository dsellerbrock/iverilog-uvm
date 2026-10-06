# Candidate OpenTitan runtime recheck (2026-10-05)

**Result: 49/49 selected runtime targets PASS.** Every row has its checked pass
banner; completed rows report zero hard errors, semantic/runtime debt, timeouts,
process-memory-limit hits, or monitor errors.

The run used the reconstructed census18 OpenTitan snapshot at
`/private/tmp/ot-corpus-current-spid-passthrough-20261003/source`, pinned UVM
1.2, the `commercial-unsafe` profile, and serial execution (`--jobs 1`). The
snapshot has no Git metadata, so its revision is `unknown` and it is marked
dirty. See the [pinned source provenance](../candidate-census18-pinned-compile-20261005/README.md#reproducible-source-overlay).

## Compiler and run identity

- Driver SHA-256: `bf0e28b53a64d3a5b06cd09613cbb1278f002b02d65200e94142023269a50d38`
- Engine SHA-256: `890c5b3c9ee0098ab4bcf4d25f06b10c3a8758a88d5e867b1a566a5ca9ecfdaa`
- VVP SHA-256: `f18c1b84c5410eee42c187365ee91b25506f2478cb075c63b39f9a3ddc5a7c0d`
- Runtime timeout: 18,000 seconds per target; process limit: 9,536 MiB.

The compiler fingerprint, source path/state, UVM tree, profile, limits, and
49-target inventory match across both segments. Only the generation time and
segment-specific build-root paths differ.

## Segmented execution

The first invocation completed 33 rows. Its 70% free-memory floor tripped at
68% while the next target was active, so the guard stopped that segment and
preserved its report. The remaining 16 targets ran with the same compiler,
sources, UVM, profile, timeout, and process limit under a 60% free-memory
floor; that segment exited 0. The interrupted target is included in the
continuation. The aggregate has no missing or duplicate rows and matches the
canonical census18 target identities and order.

Raw reports and guard logs are in [`segment-33/`](segment-33/) and
[`segment-16/`](segment-16/). The aggregate is in [`result.json`](result.json)
and [`result.md`](result.md). JSON log paths point to the original build root
under `/private/tmp/pi/iverilog-uvm-candidate-census18-20261005/`.

## Later compiler change

The later direct unbased-fill `inside` range-endpoint fix is on engine
`367e4467…`; paired 2017/2023 regressions and the patched OpenTitan UVM lane
pass on that engine (35/35). A source scan of this runtime snapshot found no
direct unbased-fill range endpoints, so this change does not affect the
selected runtime inputs. This report does not claim a full 49-target run on
engine `367e4467…`. See the [patched UVM evidence](../candidate-patched-uvm-final-20261005/README.md)
and [OTP evidence](../candidate-otp-fill-range-20261005/README.md).

The separate 309-row candidate RTL/SVA/UVM compile census still has
`DEPENDENCY_ONLY`, `DEBT`, `FAIL`, setup-failure, and upstream-invalid outcomes.
This runtime pass alone does not close that compile audit or establish full
OpenTitan completion.
