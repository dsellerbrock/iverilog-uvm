# OpenTitan Icarus matrix

- Generated: `2026-10-06T05:34:21.421416+00:00`
- OpenTitan revision: `unknown` (dirty)
- Icarus: `Icarus Verilog version 13.0 (devel) ()`
- Compiler engine SHA-256: `367e44671b5aabf7786a200c2af4c3dcbd17c449bffa3ea2bc30fbfcfbaa1abc`
- UVM/runtime compile profile: `default`
- Matrix workers: `1`
- Status counts: `DEPENDENCY_ONLY=1`

A `DEBT` result exited successfully but emitted a warning or explicit semantic degradation. It is not a conformance pass.

An `OUT_OF_SCOPE` row is excluded by explicit policy; it is not an Icarus pass.

| Lane | Core | Status | Hard errors | Semantic debt | Log / reason |
|---|---|---:|---:|---:|---|
| rtl | `lowrisc:prim:primgen:0.1` | **DEPENDENCY_ONLY** | 0 | 0 | `FuseSoC generator-only core; no standalone RTL target.` |
