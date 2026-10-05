# Pinned-source candidate compile census

This compile-only census ran the candidate compiler against the clean Earlgrey-PROD-M6 source at OpenTitan commit
`a78922f14a8cc20c7ee569f322a04626f2ac6127`, with pinned UVM 1.2 and the installed UVM DPI module. It covers the RTL, SVA, and UVM compile lanes (309 rows); it does not include the runtime lane.

The candidate was built from Icarus commit `8c16a7dc35c72b83d4a824fe0b0b128968221d45`. Its engine SHA-256 is `890c5b3c9ee0098ab4bcf4d25f06b10c3a8758a88d5e867b1a566a5ca9ecfdaa`.

| Lane | Pass | Dependency only | Fail | Debt | Setup fail | Upstream invalid |
|---|---:|---:|---:|---:|---:|---:|
| RTL | 47 | 119 | 3 | 6 | 7 | 3 |
| SVA | 74 | 1 | 0 | 7 | 0 | 7 |
| UVM | 16 | 0 | 13 | 6 | 0 | 0 |
| **Total** | **137** | **120** | **16** | **19** | **7** | **10** |

The 3 RTL hard failures are CW310/Hyperdebug/CW340 tops with unresolved Xilinx primitives. The 13 UVM compile failures include source compatibility issues in AES, chip DV, EDN, entropy, Flash, Ibex, OTBN, OTP, PWM, reset manager, SPI host, sysrst, and USB; their documented patches and focused evidence are indexed in [release overlays](../../../docs/conformance/release_overlays/README.md). Seven setup failures, ten upstream-invalid rows, and 19 debt rows remain separately classified in the full [result table](result.md).

The earlier unpinned census reported 31 UVM failures because its candidate install lacked `uvm_dpi.vpi`; that result is historical and superseded. The corrected UVM-only run passed 35/35 on the patched snapshot. This pinned full compile census deliberately uses the unmodified release to expose which compatibility overlays are required.

## Reproducible source overlay

The prior census18 runtime input had no Git metadata. Its source content is now reconstructible from the clean pinned source with [`source-overlay.patch`](source-overlay.patch), followed by the checked [Trial1 core relocation helper](../../../docs/conformance/release_overlays/opentitan/trial1_core_layout_overlay.py). The resulting 10,274-file/symlink tree matches the prior runtime input; its canonical hash and per-file hashes are recorded in [`source-provenance.json`](source-provenance.json). Python bytecode caches and `.git` metadata are excluded.

## RAM guard

The run used one matrix job, 600-second setup/compile timeouts, and the shared macOS guard with a 70% free-memory floor. It completed without tripping the guard; samples stayed at 78–79% free. The largest observed `ivl` RSS was about 3.12 GiB. The full command output and guard samples are in [`runner.log`](runner.log); structured results are in [`result.json`](result.json).

The candidate runtime lane is a separate gate. This compile result alone does not establish 49/49 candidate runtime acceptance.
