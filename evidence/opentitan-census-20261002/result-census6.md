# OpenTitan Icarus matrix

- Generated: `2026-10-02T04:22:06.802154+00:00`
- OpenTitan revision: `a78922f14a8cc20c7ee569f322a04626f2ac6127` (dirty)
- Icarus: `Icarus Verilog version 13.0 (devel) ()`
- Compiler engine SHA-256: `3d5962e6667b119d15037caff296b221c575c4efa2daf5c9471891e493c08961`
- UVM/runtime compile profile: `commercial-unsafe`
- Jobs: `49`
- Status counts: `DEBT=7`, `FAIL=2`, `PASS=37`, `RUNTIME_FAIL=3`

A `DEBT` result exited successfully but emitted a warning or explicit semantic degradation. It is not a conformance pass.

| Lane | Core | Status | Hard errors | Semantic debt | Log |
|---|---|---:|---:|---:|---|
| runtime | `lowrisc:dv:adc_ctrl_sim:0.1` | **RUNTIME_FAIL** | 0 | 4 | `/private/tmp/pi/census6/build/runtime/lowrisc_dv_adc_ctrl_sim_0.1/matrix-runtime.log` |
| runtime | `lowrisc:dv:aes_sim:0.1` | **PASS** | 0 | 0 | `/private/tmp/pi/census6/build/runtime/lowrisc_dv_aes_sim_0.1/matrix-runtime.log` |
| runtime | `lowrisc:dv:aon_timer_sim:0.1` | **PASS** | 0 | 0 | `/private/tmp/pi/census6/build/runtime/lowrisc_dv_aon_timer_sim_0.1/matrix-runtime.log` |
| runtime | `lowrisc:dv:chip_sim:0.1` | **DEBT** | 0 | 9 | `/private/tmp/pi/census6/build/runtime/lowrisc_dv_chip_sim_0.1/matrix-runtime.log` |
| runtime | `lowrisc:dv:clkmgr_sim:0.1` | **PASS** | 0 | 0 | `/private/tmp/pi/census6/build/runtime/lowrisc_dv_clkmgr_sim_0.1/matrix-runtime.log` |
| runtime | `lowrisc:dv:csrng_sim:0.1` | **PASS** | 0 | 0 | `/private/tmp/pi/census6/build/runtime/lowrisc_dv_csrng_sim_0.1/matrix-runtime.log` |
| runtime | `lowrisc:dv:edn_sim:0.1` | **PASS** | 0 | 0 | `/private/tmp/pi/census6/build/runtime/lowrisc_dv_edn_sim_0.1/matrix-runtime.log` |
| runtime | `lowrisc:dv:entropy_src_sim:0.1` | **DEBT** | 0 | 8 | `/private/tmp/pi/census6/build/runtime/lowrisc_dv_entropy_src_sim_0.1/matrix-runtime.log` |
| runtime | `lowrisc:dv:flash_ctrl_sim:0.1` | **FAIL** | 9 | 11 | `/private/tmp/pi/census6/build/runtime/lowrisc_dv_flash_ctrl_sim_0.1/matrix-compile.log` |
| runtime | `lowrisc:dv:gpio_sim:0.1` | **PASS** | 0 | 0 | `/private/tmp/pi/census6/build/runtime/lowrisc_dv_gpio_sim_0.1/matrix-runtime.log` |
| runtime | `lowrisc:dv:hmac_sim:0.1` | **PASS** | 0 | 0 | `/private/tmp/pi/census6/build/runtime/lowrisc_dv_hmac_sim_0.1/matrix-runtime.log` |
| runtime | `lowrisc:dv:i2c_sim:0.1` | **DEBT** | 0 | 5 | `/private/tmp/pi/census6/build/runtime/lowrisc_dv_i2c_sim_0.1/matrix-runtime.log` |
| runtime | `lowrisc:dv:ibex_icache_sim:0.1` | **PASS** | 0 | 0 | `/private/tmp/pi/census6/build/runtime/lowrisc_dv_ibex_icache_sim_0.1/matrix-runtime.log` |
| runtime | `lowrisc:dv:keymgr_sim:0.1` | **PASS** | 0 | 0 | `/private/tmp/pi/census6/build/runtime/lowrisc_dv_keymgr_sim_0.1/matrix-runtime.log` |
| runtime | `lowrisc:dv:kmac_sim:0.1` | **PASS** | 0 | 0 | `/private/tmp/pi/census6/build/runtime/lowrisc_dv_kmac_sim_0.1/matrix-runtime.log` |
| runtime | `lowrisc:dv:lc_ctrl_sim:0.1` | **PASS** | 0 | 0 | `/private/tmp/pi/census6/build/runtime/lowrisc_dv_lc_ctrl_sim_0.1/matrix-runtime.log` |
| runtime | `lowrisc:dv:otbn_sim:0.1` | **RUNTIME_FAIL** | 0 | 0 | `/private/tmp/pi/census6/build/runtime/lowrisc_dv_otbn_sim_0.1/matrix-runtime.log` |
| runtime | `lowrisc:dv:otp_ctrl_sim:0.1` | **DEBT** | 0 | 36 | `/private/tmp/pi/census6/build/runtime/lowrisc_dv_otp_ctrl_sim_0.1/matrix-runtime.log` |
| runtime | `lowrisc:dv:pattgen_sim:0.1` | **PASS** | 0 | 0 | `/private/tmp/pi/census6/build/runtime/lowrisc_dv_pattgen_sim_0.1/matrix-runtime.log` |
| runtime | `lowrisc:dv:prim_alert_sim:0.1` | **PASS** | 0 | 0 | `/private/tmp/pi/census6/build/runtime/lowrisc_dv_prim_alert_sim_0.1/matrix-runtime.log` |
| runtime | `lowrisc:dv:prim_esc_sim:0.1` | **PASS** | 0 | 0 | `/private/tmp/pi/census6/build/runtime/lowrisc_dv_prim_esc_sim_0.1/matrix-runtime.log` |
| runtime | `lowrisc:dv:prim_flop_2sync_sim:0.1` | **PASS** | 0 | 0 | `/private/tmp/pi/census6/build/runtime/lowrisc_dv_prim_flop_2sync_sim_0.1/matrix-runtime.log` |
| runtime | `lowrisc:dv:prim_lfsr_sim:0.1` | **PASS** | 0 | 0 | `/private/tmp/pi/census6/build/runtime/lowrisc_dv_prim_lfsr_sim_0.1/matrix-runtime.log` |
| runtime | `lowrisc:dv:prim_present_sim:0.1` | **PASS** | 0 | 0 | `/private/tmp/pi/census6/build/runtime/lowrisc_dv_prim_present_sim_0.1/matrix-runtime.log` |
| runtime | `lowrisc:dv:prim_prince_sim:0.1` | **PASS** | 0 | 0 | `/private/tmp/pi/census6/build/runtime/lowrisc_dv_prim_prince_sim_0.1/matrix-runtime.log` |
| runtime | `lowrisc:dv:pwm_sim:0.1` | **PASS** | 0 | 0 | `/private/tmp/pi/census6/build/runtime/lowrisc_dv_pwm_sim_0.1/matrix-runtime.log` |
| runtime | `lowrisc:dv:pwrmgr_sim:0.1` | **PASS** | 0 | 0 | `/private/tmp/pi/census6/build/runtime/lowrisc_dv_pwrmgr_sim_0.1/matrix-runtime.log` |
| runtime | `lowrisc:dv:rom_ctrl_sim:0.1` | **PASS** | 0 | 0 | `/private/tmp/pi/census6/build/runtime/lowrisc_dv_rom_ctrl_sim_0.1/matrix-runtime.log` |
| runtime | `lowrisc:dv:rstmgr_cnsty_chk_sim:0.1` | **PASS** | 0 | 0 | `/private/tmp/pi/census6/build/runtime/lowrisc_dv_rstmgr_cnsty_chk_sim_0.1/matrix-runtime.log` |
| runtime | `lowrisc:dv:rstmgr_sim:0.1` | **PASS** | 0 | 0 | `/private/tmp/pi/census6/build/runtime/lowrisc_dv_rstmgr_sim_0.1/matrix-runtime.log` |
| runtime | `lowrisc:dv:rv_dm_sim:0.1` | **PASS** | 0 | 0 | `/private/tmp/pi/census6/build/runtime/lowrisc_dv_rv_dm_sim_0.1/matrix-runtime.log` |
| runtime | `lowrisc:dv:rv_timer_sim:0.1` | **PASS** | 0 | 0 | `/private/tmp/pi/census6/build/runtime/lowrisc_dv_rv_timer_sim_0.1/matrix-runtime.log` |
| runtime | `lowrisc:dv:spi_device_sim:0.1` | **DEBT** | 0 | 1 | `/private/tmp/pi/census6/build/runtime/lowrisc_dv_spi_device_sim_0.1/matrix-runtime.log` |
| runtime | `lowrisc:dv:spi_host_sim:1.0` | **PASS** | 0 | 0 | `/private/tmp/pi/census6/build/runtime/lowrisc_dv_spi_host_sim_1.0/matrix-runtime.log` |
| runtime | `lowrisc:dv:spi_tpm_sim:0.1` | **FAIL** | 3 | 0 | `/private/tmp/pi/census6/build/runtime/lowrisc_dv_spi_tpm_sim_0.1/matrix-compile.log` |
| runtime | `lowrisc:dv:spid_jedec_sim:0.1` | **PASS** | 0 | 0 | `/private/tmp/pi/census6/build/runtime/lowrisc_dv_spid_jedec_sim_0.1/matrix-runtime.log` |
| runtime | `lowrisc:dv:spid_passthrough_sim:0.1` | **DEBT** | 0 | 11 | `/private/tmp/pi/census6/build/runtime/lowrisc_dv_spid_passthrough_sim_0.1/matrix-runtime.log` |
| runtime | `lowrisc:dv:spid_readcmd_sim:0.1` | **PASS** | 0 | 0 | `/private/tmp/pi/census6/build/runtime/lowrisc_dv_spid_readcmd_sim_0.1/matrix-runtime.log` |
| runtime | `lowrisc:dv:spid_status_sim:0.1` | **PASS** | 0 | 0 | `/private/tmp/pi/census6/build/runtime/lowrisc_dv_spid_status_sim_0.1/matrix-runtime.log` |
| runtime | `lowrisc:dv:spid_upload_sim:0.1` | **RUNTIME_FAIL** | 0 | 0 | `/private/tmp/pi/census6/build/runtime/lowrisc_dv_spid_upload_sim_0.1/matrix-runtime.log` |
| runtime | `lowrisc:dv:sram_ctrl_sim:0.1` | **PASS** | 0 | 0 | `/private/tmp/pi/census6/build/runtime/lowrisc_dv_sram_ctrl_sim_0.1/matrix-runtime.log` |
| runtime | `lowrisc:dv:sysrst_ctrl_sim:0.1` | **PASS** | 0 | 0 | `/private/tmp/pi/census6/build/runtime/lowrisc_dv_sysrst_ctrl_sim_0.1/matrix-runtime.log` |
| runtime | `lowrisc:dv:tl_agent_sim:0.1` | **PASS** | 0 | 0 | `/private/tmp/pi/census6/build/runtime/lowrisc_dv_tl_agent_sim_0.1/matrix-runtime.log` |
| runtime | `lowrisc:dv:top_earlgrey_xbar_main_sim:0.1` | **PASS** | 0 | 0 | `/private/tmp/pi/census6/build/runtime/lowrisc_dv_top_earlgrey_xbar_main_sim_0.1/matrix-runtime.log` |
| runtime | `lowrisc:dv:top_earlgrey_xbar_peri_sim:0.1` | **PASS** | 0 | 0 | `/private/tmp/pi/census6/build/runtime/lowrisc_dv_top_earlgrey_xbar_peri_sim_0.1/matrix-runtime.log` |
| runtime | `lowrisc:dv:uart_sim:0.1` | **PASS** | 0 | 0 | `/private/tmp/pi/census6/build/runtime/lowrisc_dv_uart_sim_0.1/matrix-runtime.log` |
| runtime | `lowrisc:dv:usbdev_sim:0.1` | **PASS** | 0 | 0 | `/private/tmp/pi/census6/build/runtime/lowrisc_dv_usbdev_sim_0.1/matrix-runtime.log` |
| runtime | `lowrisc:ip:trial1_sim:0.1` | **DEBT** | 0 | 0 | `/private/tmp/pi/census6/build/runtime/lowrisc_ip_trial1_sim_0.1/matrix-runtime.log` |
| runtime | `lowrisc:opentitan:top_earlgrey_alert_handler_sim:0.1` | **PASS** | 0 | 0 | `/private/tmp/pi/census6/build/runtime/lowrisc_opentitan_top_earlgrey_alert_handler_sim_0.1/matrix-runtime.log` |
