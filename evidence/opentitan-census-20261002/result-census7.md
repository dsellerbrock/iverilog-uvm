# OpenTitan Icarus matrix

- Generated: `2026-10-02T19:16:14.885370+00:00`
- OpenTitan revision: `a78922f14a8cc20c7ee569f322a04626f2ac6127` (dirty)
- Icarus: `Icarus Verilog version 13.0 (devel) ()`
- Compiler engine SHA-256: `7ef013b4a31824e20ba283e4338311a8a6ff3c9ac846443f50f6684fdd4ac759`
- UVM/runtime compile profile: `commercial-unsafe`
- Jobs: `4`
- Status counts: `PASS=3`, `RUNTIME_FAIL=1`

A `DEBT` result exited successfully but emitted a warning or explicit semantic degradation. It is not a conformance pass.

| Lane | Core | Status | Hard errors | Semantic debt | Log |
|---|---|---:|---:|---:|---|
| runtime | `lowrisc:dv:adc_ctrl_sim:0.1` | **RUNTIME_FAIL** | 0 | 4 | `/private/tmp/pi/census7/build/runtime/lowrisc_dv_adc_ctrl_sim_0.1/matrix-runtime.log` |
| runtime | `lowrisc:dv:aes_sim:0.1` | **PASS** | 0 | 0 | `/private/tmp/pi/census7/build/runtime/lowrisc_dv_aes_sim_0.1/matrix-runtime.log` |
| runtime | `lowrisc:dv:aon_timer_sim:0.1` | **PASS** | 0 | 0 | `/private/tmp/pi/census7/build/runtime/lowrisc_dv_aon_timer_sim_0.1/matrix-runtime.log` |
| runtime | `lowrisc:dv:clkmgr_sim:0.1` | **PASS** | 0 | 0 | `/private/tmp/pi/census7/build/runtime/lowrisc_dv_clkmgr_sim_0.1/matrix-runtime.log` |
