# OpenTitan Icarus matrix — partial current-image snapshot

**Interrupted after 10 of 49 runtime rows; this is not a complete census.** The current-image snapshot contains 8 PASS and 2 DEBT rows. The remaining 39 rows were not completed.

- Generated: `2026-10-02T19:26:48.168956+00:00`
- OpenTitan revision: `a78922f14a8cc20c7ee569f322a04626f2ac6127` (dirty)
- Icarus: `Icarus Verilog version 13.0 (devel) ()`
- Compiler engine SHA-256: `6a18cb3c8c4da86ad3e230935d8085635ea015e9fbf24eb4f6e07a8fd6ed384b`
- UVM/runtime compile profile: `commercial-unsafe`
- Completed rows: `10/49` (two worker jobs; census interrupted)
- Status counts: `DEBT=2`, `PASS=8`

A `DEBT` result exited successfully but emitted a warning or explicit semantic degradation. It is not a conformance pass.

| Lane | Core | Status | Hard errors | Semantic debt | Log |
|---|---|---:|---:|---:|---|
| runtime | `lowrisc:dv:adc_ctrl_sim:0.1` | **PASS** | 0 | 0 | `/private/tmp/pi/census9/build/runtime/lowrisc_dv_adc_ctrl_sim_0.1/matrix-runtime.log` |
| runtime | `lowrisc:dv:aes_sim:0.1` | **PASS** | 0 | 0 | `/private/tmp/pi/census9/build/runtime/lowrisc_dv_aes_sim_0.1/matrix-runtime.log` |
| runtime | `lowrisc:dv:aon_timer_sim:0.1` | **PASS** | 0 | 0 | `/private/tmp/pi/census9/build/runtime/lowrisc_dv_aon_timer_sim_0.1/matrix-runtime.log` |
| runtime | `lowrisc:dv:chip_sim:0.1` | **DEBT** | 0 | 9 | `/private/tmp/pi/census9/build/runtime/lowrisc_dv_chip_sim_0.1/matrix-runtime.log` |
| runtime | `lowrisc:dv:clkmgr_sim:0.1` | **PASS** | 0 | 0 | `/private/tmp/pi/census9/build/runtime/lowrisc_dv_clkmgr_sim_0.1/matrix-runtime.log` |
| runtime | `lowrisc:dv:csrng_sim:0.1` | **PASS** | 0 | 0 | `/private/tmp/pi/census9/build/runtime/lowrisc_dv_csrng_sim_0.1/matrix-runtime.log` |
| runtime | `lowrisc:dv:edn_sim:0.1` | **PASS** | 0 | 0 | `/private/tmp/pi/census9/build/runtime/lowrisc_dv_edn_sim_0.1/matrix-runtime.log` |
| runtime | `lowrisc:dv:entropy_src_sim:0.1` | **DEBT** | 0 | 8 | `/private/tmp/pi/census9/build/runtime/lowrisc_dv_entropy_src_sim_0.1/matrix-runtime.log` |
| runtime | `lowrisc:dv:gpio_sim:0.1` | **PASS** | 0 | 0 | `/private/tmp/pi/census9/build/runtime/lowrisc_dv_gpio_sim_0.1/matrix-runtime.log` |
| runtime | `lowrisc:dv:hmac_sim:0.1` | **PASS** | 0 | 0 | `/private/tmp/pi/census9/build/runtime/lowrisc_dv_hmac_sim_0.1/matrix-runtime.log` |
