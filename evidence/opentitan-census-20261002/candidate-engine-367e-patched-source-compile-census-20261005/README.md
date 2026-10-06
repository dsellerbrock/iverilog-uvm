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
outcomes in the raw census also included three Earl Grey Xilinx-board tops
missing vendor primitives, seven setup failures, two upstream-invalid rows,
and one Earl Grey ASIC SVA debt.

## Scope review — 2026-10-06

Per project direction, Xilinx board-level tops are outside Icarus qualification
because Vivado owns those vendor primitives. Their rows are recorded as
`OUT_OF_SCOPE`, not as passes. The [scope review](board-primitive-scope-review-20261006/README.md)
and [scoped aggregate](result-scoped-aggregate.md) preserve all 309 rows: 4 are
out of scope and 305 remain in scope. Current in-scope counts are 188 PASS and
117 dependency-only, with no FAIL, DEBT, setup-fail, or upstream-invalid rows.
Focused replays directly compile six previously uncovered providers and select
the declared simulation targets for the Ibex wrappers and EnglishBreakfast
Verilator wrapper. The Ibex compliance and simple-system cosim targets pass
using the exact support library pinned by OpenTitan; both EnglishBreakfast
`topgen` helpers remain dependency-only.
The EnglishBreakfast Verilator target passes the Icarus compile after the
runner mirrors the target's `VERILATOR` define. Its target omits Verilator-only
C/C++ sources and runtime image arguments from Icarus setup; this is a compile
result, not a runtime qualification. `chip_englishbreakfast_cw305` remains
outside scope under the board policy. The generated `top_englishbreakfast`
passes after checking its default-empty
boot-ROM parameter and guarding only the simulator path-print block; `$readmemh`
is preserved. The chip ASIC SVA row now passes with its common DV `1ns/1ps`
default; Icarus's mixed-timescale notice remains visible as benign. See the
[Ibex replay](ibex-target-profile-replay-20261006/README.md),
[EnglishBreakfast target replay](englishbreakfast-rtl-replay-r3-20261006/result.md),
[Verilator follow-up](englishbreakfast-rtl-replay-r5-20261006/result.md),
[generated top replay](englishbreakfast-rtl-replay-r6-20261006/result.md), and
[Earl Grey SVA replay](chip-earlgrey-sva-replay-r8-20261006/result.md), plus
the updated scoped aggregate.

Of the 117 dependency-only rows, 116 are helper cores compiled through passing
parent top levels; `primgen` is generator-only and is exercised by passing
parents. The exact Ibex support files and hashes are in
[`ibex-sim-shared-38c07093`](ibex-sim-shared-38c07093/README.md), with the
[compliance replay](ibex-support-replay-r1-20261006/result.md),
[simple-system replay](ibex-simple-system-cosim-replay-r2-20261006/result.md),
[provider replay](orphan-provider-replay-r3-20261006/result.md), and
[generator classification](primgen-generator-classification-20261006/result.md).
This is compile-only; the selected 49-target runtime gate separately passes
49/49 on engine 367e and does not represent the full OpenTitan DV suite.

To reconstruct the source snapshot from the pinned release, use the
[source overlay and provenance](../candidate-census18-pinned-compile-20261005/README.md#reproducible-source-overlay).
The [aggregate table](result-aggregate.md) contains every row.
