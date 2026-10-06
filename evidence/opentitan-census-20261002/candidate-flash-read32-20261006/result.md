# OpenTitan Icarus matrix

- Generated: `2026-10-06T14:27:44.370841+00:00`
- OpenTitan revision: `unknown` (dirty)
- Icarus: `Icarus Verilog version 13.0 (devel) ()`
- Compiler engine SHA-256: `367e44671b5aabf7786a200c2af4c3dcbd17c449bffa3ea2bc30fbfcfbaa1abc`
- UVM/runtime compile profile: `commercial-unsafe`
- Matrix workers: `1`
- Status counts: `RUNTIME_FAIL=1`

A `DEBT` result exited successfully but emitted a warning or explicit semantic degradation. It is not a conformance pass.

An `OUT_OF_SCOPE` row is excluded by explicit policy; it is not an Icarus pass.

| Lane | Core | Status | Hard errors | Semantic debt | Log / reason |
|---|---|---:|---:|---:|---|
| runtime | `lowrisc:dv:flash_ctrl_sim:0.1` | **RUNTIME_FAIL** | 0 | 0 | `/private/tmp/pi/iverilog-uvm-flash-read32-20261006/runtime/lowrisc_dv_flash_ctrl_sim_0.1/matrix-runtime.log` |
