# OpenTitan patched-source compile census — engine 367e

This compile-only recheck processed all 309 RTL, SVA, and UVM rows using the
reproducible patched source snapshot based on OpenTitan
`a78922f14a8cc20c7ee569f322a04626f2ac6127`. It used compiler engine
`367e44671b5aabf7786a200c2af4c3dcbd17c449bffa3ea2bc30fbfcfbaa1abc`, UVM 1.2,
`-gcommercial-unsafe`, one job, and 600-second setup and compile limits.

| Lane | PASS | Dependency only | DEBT | FAIL | Setup fail | Upstream invalid |
|---|---:|---:|---:|---:|---:|---:|
| RTL | 54 | 119 | 0 | 3 | 7 | 2 |
| SVA | 87 | 1 | 1 | 0 | 0 | 0 |
| UVM | 35 | 0 | 0 | 0 | 0 | 0 |
| **Total** | **176** | **120** | **1** | **3** | **7** | **2** |

The raw 309-row run had one `SOURCE_OVERLAY_FAIL`: the source snapshot already
contained the exact hash-checked Ibex tracer overlay. Making that staging
idempotent and replaying only `chip_earlgrey_verilator` passed. The
[aggregate result](result-aggregate.json) replaces only that row; the original
[full-run result](result.json), [focused replay](chip-verilator-replay/result.json),
and [runner log](runner.log) are preserved.

All 35 UVM rows pass in this patched source profile. The remaining direct
outcomes are three Earl Grey Xilinx-board tops missing vendor primitives, seven
setup failures, two upstream-invalid rows, and one Earl Grey ASIC SVA debt. The
120 dependency-only rows have no standalone top-level; their parent compile
coverage still needs explicit mapping. This is not a 309/309 clean result and
does not include runtime. The selected 49-target runtime gate separately
passes 49/49 on engine 367e.

To reconstruct the source snapshot from the pinned release, use the
[source overlay and provenance](../candidate-census18-pinned-compile-20261005/README.md#reproducible-source-overlay).
The [aggregate table](result-aggregate.md) contains every row.
