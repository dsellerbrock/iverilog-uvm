# Census18 candidate compile lanes — historical diagnostic

This first 309-row result is superseded by the [pinned-source candidate census](../candidate-census18-pinned-compile-20261005/README.md). It used an unpinned source copy and an install missing `uvm_dpi.vpi`; its UVM failure counts are not the current status. Keep the raw files below as historical diagnostics.

This refresh evaluated the candidate compiler on the RTL, SVA, and UVM lanes
after the separate census18 runtime run reached 49/49. It completed all 309
lane entries with one matrix job at a time. This is not a passing candidate
census and it did not include the runtime lane.

| Lane | Pass | Dependency only | Fail | Debt | Setup fail | Upstream invalid |
|---|---:|---:|---:|---:|---:|---:|
| RTL | 50 | 119 | 3 | 3 | 7 | 3 |
| SVA | 75 | 1 | 0 | 6 | 0 | 7 |
| UVM | 0 | 0 | 31 | 4 | 0 | 0 |
| **Total** | **125** | **120** | **34** | **13** | **7** | **10** |

## Blocking results

- The 31 UVM `FAIL` rows shared a setup cause: the candidate install lacked the
  bundled standard UVM DPI runtime. The driver fell back to `UVM_NO_DPI`, whose
  stub `uvm_hdl_release` signature rejected OpenTitan's normal one-argument DPI
  calls. Installing `uvm_dpi.vpi` removed that failure; the corrected UVM-only
  lane passed 35/35 on the patched source copy. This does not replace the
  pinned-source full compile census linked above.
- Three RTL failures are board tops with unresolved Xilinx primitives such as
  `MMCME2_ADV`, `BUFG`, and `USR_ACCESSE2`.
- The seven RTL setup failures include FuseSoC `NoneType.toplevel` errors and
  conflicting-core requirements. The remaining RTL/SVA debt and upstream
  invalid rows are detailed in `result.md` and `result.json`.

The earlier 49/49 result used the installed **pre-candidate** compiler. This
historical candidate compile run did not use a pinned source checkout; consult
the pinned census and candidate runtime evidence for current acceptance.

## RAM guard

The run used `--jobs 1`, 600-second per-core compile timeouts, and
[`ram_guard.py`](ram_guard.py), which samples macOS system free memory every
five seconds and interrupts the run below 70% free. Samples ranged from 79% to
83% free; the guard did not trip. Process inspection observed the largest
`ivl` RSS at about 3.27 million KiB (about 3.12 GiB). No runtime processes were
part of this census.

## Reproducibility limits

The candidate compiler was built from repository commit `8c16a7dc3` in a clean
archive and installed separately under `/private/tmp`; its driver SHA-256 is
`bf0e28b53a64d3a5b06cd09613cbb1278f002b02d65200e94142023269a50d38`, and its
`ivl` engine SHA-256 is
`890c5b3c9ee0098ab4bcf4d25f06b10c3a8758a88d5e867b1a566a5ca9ecfdaa`.

The OpenTitan source copy had no Git metadata. The matrix records its revision
as `unknown` and `dirty: true`; treat this result as diagnostic evidence, not
as the final pinned-source acceptance census. The raw structured results are
in `result.json`, the row table is in `result.md`, and the guard-wrapped runner
output is in `runner.log`. Per-core build logs remain under the local
`/private/tmp/pi/opentitan-candidate-census18-20261005/build` directory.
