# OpenTitan Icarus matrix

- Generated: `2026-10-06T04:05:36.144200+00:00`
- OpenTitan revision: `unknown` (dirty)
- Icarus: `Icarus Verilog version 13.0 (devel) ()`
- Compiler engine SHA-256: `367e44671b5aabf7786a200c2af4c3dcbd17c449bffa3ea2bc30fbfcfbaa1abc`
- UVM/runtime compile profile: `default`
- Matrix workers: `1`
- Status counts: `DEBT=1`, `DEPENDENCY_ONLY=2`, `FAIL=1`, `OUT_OF_SCOPE=1`

A `DEBT` result exited successfully but emitted a warning or explicit semantic degradation. It is not a conformance pass.

An `OUT_OF_SCOPE` row is excluded by explicit policy; it is not an Icarus pass.

| Lane | Core | Status | Hard errors | Semantic debt | Log / reason |
|---|---|---:|---:|---:|---|
| rtl | `lowrisc:systems:chip_englishbreakfast_cw305:0.1` | **OUT_OF_SCOPE** | 0 | 0 | `CW305 Xilinx 7-series primitives are handled by Vivado; excluded from Icarus qualification.` |
| rtl | `lowrisc:systems:chip_englishbreakfast_verilator:0.1` | **FAIL** | 8 | 4 | `/private/tmp/pi/iverilog-uvm-englishbreakfast-replay-r3-20261006/build/rtl/lowrisc_systems_chip_englishbreakfast_verilator_0.1/matrix-compile.log` |
| rtl | `lowrisc:systems:top_englishbreakfast:0.1` | **DEBT** | 0 | 1 | `/private/tmp/pi/iverilog-uvm-englishbreakfast-replay-r3-20261006/build/rtl/lowrisc_systems_top_englishbreakfast_0.1/matrix-compile.log` |
| rtl | `lowrisc:systems:topgen-reg-only:0` | **DEPENDENCY_ONLY** | 0 | 0 | `/private/tmp/pi/iverilog-uvm-englishbreakfast-replay-r3-20261006/build/rtl/lowrisc_systems_topgen-reg-only_0/matrix-setup.log` |
| rtl | `lowrisc:systems:topgen:0` | **DEPENDENCY_ONLY** | 0 | 0 | `/private/tmp/pi/iverilog-uvm-englishbreakfast-replay-r3-20261006/build/rtl/lowrisc_systems_topgen_0/matrix-setup.log` |
