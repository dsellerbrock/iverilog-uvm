# OpenTitan Icarus matrix

- Generated: `2026-09-25T20:38:10.200686+00:00`
- OpenTitan revision: `a78922f14a8cc20c7ee569f322a04626f2ac6127`
- Icarus: `Icarus Verilog version 13.0 (devel) ()`
- Compiler engine SHA-256: `9084fca0b6d1cbe00184583399ba1c5fcf0f10d78402f42c14fd50c3708dbdfe`
- UVM/runtime compile profile: `commercial-unsafe`
- Jobs: `2`
- Status counts: `DEBT=1`, `RUNTIME_FAIL=1`

A `DEBT` result exited successfully but emitted a warning or explicit semantic degradation. It is not a conformance pass.

| Lane | Core | Status | Hard errors | Semantic debt | Log |
|---|---|---:|---:|---:|---|
| uvm | `lowrisc:dv:hmac_sim:0.1` | **DEBT** | 0 | 13 | `/private/tmp/ot-open-range-hmac-combined-20260925/work/uvm/lowrisc_dv_hmac_sim_0.1/matrix-compile.log` |
| runtime | `lowrisc:dv:hmac_sim:0.1` | **RUNTIME_FAIL** | 0 | 13 | `/private/tmp/ot-open-range-hmac-combined-20260925/work/runtime/lowrisc_dv_hmac_sim_0.1/matrix-runtime.log` |
