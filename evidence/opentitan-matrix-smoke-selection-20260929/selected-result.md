# OpenTitan Icarus matrix

- Generated: `2026-09-29T18:24:24.829947+00:00`
- OpenTitan revision: `a78922f14a8cc20c7ee569f322a04626f2ac6127` (dirty)
- Icarus: `Icarus Verilog version 13.0 (devel) ()`
- Compiler engine SHA-256: `2b24c2854756c53c8bd51d8d19906e820700a7fd0d34dbfe4d56de7f3befb0a4`
- UVM/runtime compile profile: `commercial-unsafe`
- Jobs: `2`
- Status counts: `DEBT=1`, `PASS=1`

A `DEBT` result exited successfully but emitted a warning or explicit semantic degradation. It is not a conformance pass.

| Lane | Core | Status | Hard errors | Semantic debt | Log |
|---|---|---:|---:|---:|---|
| runtime | `lowrisc:dv:rv_timer_sim:0.1` | **PASS** | 0 | 0 | `/private/tmp/ot-smoke-selector-selected-20260929/work/runtime/lowrisc_dv_rv_timer_sim_0.1/matrix-runtime.log` |
| runtime | `lowrisc:dv:spi_device_sim:0.1` | **DEBT** | 0 | 5 | `/private/tmp/ot-smoke-selector-selected-20260929/work/runtime/lowrisc_dv_spi_device_sim_0.1/matrix-runtime.log` |
