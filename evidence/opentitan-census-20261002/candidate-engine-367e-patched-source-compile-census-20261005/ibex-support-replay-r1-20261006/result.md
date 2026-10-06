# OpenTitan Icarus matrix

- Generated: `2026-10-06T05:39:22.483547+00:00`
- OpenTitan revision: `unknown` (dirty)
- Icarus: `Icarus Verilog version 13.0 (devel) ()`
- Compiler engine SHA-256: `367e44671b5aabf7786a200c2af4c3dcbd17c449bffa3ea2bc30fbfcfbaa1abc`
- UVM/runtime compile profile: `default`
- Matrix workers: `1`
- Status counts: `DEBT=1`, `PASS=1`

A `DEBT` result exited successfully but emitted a warning or explicit semantic degradation. It is not a conformance pass.

An `OUT_OF_SCOPE` row is excluded by explicit policy; it is not an Icarus pass.

| Lane | Core | Status | Hard errors | Semantic debt | Log / reason |
|---|---|---:|---:|---:|---|
| rtl | `lowrisc:ibex:ibex_riscv_compliance:0.1` | **PASS** | 0 | 0 | `/private/tmp/pi/ibex-support-replay-r1-20261006/build/rtl/lowrisc_ibex_ibex_riscv_compliance_0.1/matrix-compile.log` |
| rtl | `lowrisc:ibex:ibex_simple_system_cosim:0` | **DEBT** | 0 | 0 | `/private/tmp/pi/ibex-support-replay-r1-20261006/build/rtl/lowrisc_ibex_ibex_simple_system_cosim_0/matrix-compile.log` |
