# OpenTitan Icarus matrix

- Generated: `2026-09-25T20:40:58.377453+00:00`
- OpenTitan revision: `a78922f14a8cc20c7ee569f322a04626f2ac6127`
- Icarus: `Icarus Verilog version 13.0 (devel) ()`
- Compiler engine SHA-256: `9084fca0b6d1cbe00184583399ba1c5fcf0f10d78402f42c14fd50c3708dbdfe`
- UVM/runtime compile profile: `commercial-unsafe`
- Jobs: `84`
- Status counts: `DEBT=16`, `FAIL=61`, `RUNTIME_FAIL=6`, `RUNTIME_TIMEOUT=1`

A `DEBT` result exited successfully but emitted a warning or explicit semantic degradation. It is not a conformance pass.

Log labels identify members of the [preserved archive](latest-unsafe-matrix-logs.tar.gz); their [SHA-256 manifest](latest-unsafe-matrix-log-hashes.json) verifies each file.

| Lane | Core | Status | Hard errors | Semantic debt | Log |
|---|---|---:|---:|---:|---|
| uvm | `lowrisc:dv:adc_ctrl_sim:0.1` | **DEBT** | 0 | 32 | [`uvm/lowrisc_dv_adc_ctrl_sim_0.1/matrix-compile.log`](latest-unsafe-matrix-logs.tar.gz) |
| uvm | `lowrisc:dv:aes_sim:0.1` | **FAIL** | 3 | 6 | [`uvm/lowrisc_dv_aes_sim_0.1/matrix-compile.log`](latest-unsafe-matrix-logs.tar.gz) |
| uvm | `lowrisc:dv:aon_timer_sim:0.1` | **DEBT** | 0 | 14 | [`uvm/lowrisc_dv_aon_timer_sim_0.1/matrix-compile.log`](latest-unsafe-matrix-logs.tar.gz) |
| uvm | `lowrisc:dv:chip_sim:0.1` | **FAIL** | 31 | 89 | [`uvm/lowrisc_dv_chip_sim_0.1/matrix-compile.log`](latest-unsafe-matrix-logs.tar.gz) |
| uvm | `lowrisc:dv:clkmgr_sim:0.1` | **FAIL** | 19 | 9 | [`uvm/lowrisc_dv_clkmgr_sim_0.1/matrix-compile.log`](latest-unsafe-matrix-logs.tar.gz) |
| uvm | `lowrisc:dv:csrng_sim:0.1` | **FAIL** | 4 | 29 | [`uvm/lowrisc_dv_csrng_sim_0.1/matrix-compile.log`](latest-unsafe-matrix-logs.tar.gz) |
| uvm | `lowrisc:dv:edn_sim:0.1` | **FAIL** | 3 | 21 | [`uvm/lowrisc_dv_edn_sim_0.1/matrix-compile.log`](latest-unsafe-matrix-logs.tar.gz) |
| uvm | `lowrisc:dv:entropy_src_sim:0.1` | **FAIL** | 4 | 2 | [`uvm/lowrisc_dv_entropy_src_sim_0.1/matrix-compile.log`](latest-unsafe-matrix-logs.tar.gz) |
| uvm | `lowrisc:dv:flash_ctrl_sim:0.1` | **FAIL** | 131 | 0 | [`uvm/lowrisc_dv_flash_ctrl_sim_0.1/matrix-compile.log`](latest-unsafe-matrix-logs.tar.gz) |
| uvm | `lowrisc:dv:gpio_sim:0.1` | **DEBT** | 0 | 13 | [`uvm/lowrisc_dv_gpio_sim_0.1/matrix-compile.log`](latest-unsafe-matrix-logs.tar.gz) |
| uvm | `lowrisc:dv:hmac_sim:0.1` | **DEBT** | 0 | 13 | [`uvm/lowrisc_dv_hmac_sim_0.1/matrix-compile.log`](latest-unsafe-matrix-logs.tar.gz) |
| uvm | `lowrisc:dv:i2c_sim:0.1` | **FAIL** | 18 | 34 | [`uvm/lowrisc_dv_i2c_sim_0.1/matrix-compile.log`](latest-unsafe-matrix-logs.tar.gz) |
| uvm | `lowrisc:dv:ibex_icache_sim:0.1` | **FAIL** | 1 | 0 | [`uvm/lowrisc_dv_ibex_icache_sim_0.1/matrix-compile.log`](latest-unsafe-matrix-logs.tar.gz) |
| uvm | `lowrisc:dv:keymgr_sim:0.1` | **FAIL** | 2 | 0 | [`uvm/lowrisc_dv_keymgr_sim_0.1/matrix-compile.log`](latest-unsafe-matrix-logs.tar.gz) |
| uvm | `lowrisc:dv:kmac_sim:0.1` | **FAIL** | 17 | 3 | [`uvm/lowrisc_dv_kmac_sim_0.1/matrix-compile.log`](latest-unsafe-matrix-logs.tar.gz) |
| uvm | `lowrisc:dv:lc_ctrl_sim:0.1` | **FAIL** | 6 | 20 | [`uvm/lowrisc_dv_lc_ctrl_sim_0.1/matrix-compile.log`](latest-unsafe-matrix-logs.tar.gz) |
| uvm | `lowrisc:dv:otbn_sim:0.1` | **FAIL** | 233 | 33 | [`uvm/lowrisc_dv_otbn_sim_0.1/matrix-compile.log`](latest-unsafe-matrix-logs.tar.gz) |
| uvm | `lowrisc:dv:otp_ctrl_sim:0.1` | **FAIL** | 15 | 83 | [`uvm/lowrisc_dv_otp_ctrl_sim_0.1/matrix-compile.log`](latest-unsafe-matrix-logs.tar.gz) |
| uvm | `lowrisc:dv:pattgen_sim:0.1` | **DEBT** | 0 | 40 | [`uvm/lowrisc_dv_pattgen_sim_0.1/matrix-compile.log`](latest-unsafe-matrix-logs.tar.gz) |
| uvm | `lowrisc:dv:pwm_sim:0.1` | **FAIL** | 8 | 27 | [`uvm/lowrisc_dv_pwm_sim_0.1/matrix-compile.log`](latest-unsafe-matrix-logs.tar.gz) |
| uvm | `lowrisc:dv:pwrmgr_sim:0.1` | **DEBT** | 0 | 14 | [`uvm/lowrisc_dv_pwrmgr_sim_0.1/matrix-compile.log`](latest-unsafe-matrix-logs.tar.gz) |
| uvm | `lowrisc:dv:rom_ctrl_sim:0.1` | **FAIL** | 1 | 4 | [`uvm/lowrisc_dv_rom_ctrl_sim_0.1/matrix-compile.log`](latest-unsafe-matrix-logs.tar.gz) |
| uvm | `lowrisc:dv:rstmgr_sim:0.1` | **FAIL** | 11 | 21 | [`uvm/lowrisc_dv_rstmgr_sim_0.1/matrix-compile.log`](latest-unsafe-matrix-logs.tar.gz) |
| uvm | `lowrisc:dv:rv_dm_sim:0.1` | **FAIL** | 3 | 14 | [`uvm/lowrisc_dv_rv_dm_sim_0.1/matrix-compile.log`](latest-unsafe-matrix-logs.tar.gz) |
| uvm | `lowrisc:dv:rv_timer_sim:0.1` | **FAIL** | 5 | 10 | [`uvm/lowrisc_dv_rv_timer_sim_0.1/matrix-compile.log`](latest-unsafe-matrix-logs.tar.gz) |
| uvm | `lowrisc:dv:spi_device_sim:0.1` | **FAIL** | 3 | 71 | [`uvm/lowrisc_dv_spi_device_sim_0.1/matrix-compile.log`](latest-unsafe-matrix-logs.tar.gz) |
| uvm | `lowrisc:dv:spi_host_sim:1.0` | **FAIL** | 2 | 14 | [`uvm/lowrisc_dv_spi_host_sim_1.0/matrix-compile.log`](latest-unsafe-matrix-logs.tar.gz) |
| uvm | `lowrisc:dv:sram_ctrl_sim:0.1` | **FAIL** | 3 | 8 | [`uvm/lowrisc_dv_sram_ctrl_sim_0.1/matrix-compile.log`](latest-unsafe-matrix-logs.tar.gz) |
| uvm | `lowrisc:dv:sysrst_ctrl_sim:0.1` | **FAIL** | 8 | 4 | [`uvm/lowrisc_dv_sysrst_ctrl_sim_0.1/matrix-compile.log`](latest-unsafe-matrix-logs.tar.gz) |
| uvm | `lowrisc:dv:tl_agent_sim:0.1` | **DEBT** | 0 | 0 | [`uvm/lowrisc_dv_tl_agent_sim_0.1/matrix-compile.log`](latest-unsafe-matrix-logs.tar.gz) |
| uvm | `lowrisc:dv:top_earlgrey_xbar_main_sim:0.1` | **DEBT** | 0 | 0 | [`uvm/lowrisc_dv_top_earlgrey_xbar_main_sim_0.1/matrix-compile.log`](latest-unsafe-matrix-logs.tar.gz) |
| uvm | `lowrisc:dv:top_earlgrey_xbar_peri_sim:0.1` | **DEBT** | 0 | 0 | [`uvm/lowrisc_dv_top_earlgrey_xbar_peri_sim_0.1/matrix-compile.log`](latest-unsafe-matrix-logs.tar.gz) |
| uvm | `lowrisc:dv:uart_sim:0.1` | **FAIL** | 2 | 0 | [`uvm/lowrisc_dv_uart_sim_0.1/matrix-compile.log`](latest-unsafe-matrix-logs.tar.gz) |
| uvm | `lowrisc:dv:usbdev_sim:0.1` | **FAIL** | 10 | 18 | [`uvm/lowrisc_dv_usbdev_sim_0.1/matrix-compile.log`](latest-unsafe-matrix-logs.tar.gz) |
| uvm | `lowrisc:opentitan:top_earlgrey_alert_handler_sim:0.1` | **FAIL** | 11 | 83 | [`uvm/lowrisc_opentitan_top_earlgrey_alert_handler_sim_0.1/matrix-compile.log`](latest-unsafe-matrix-logs.tar.gz) |
| runtime | `lowrisc:dv:adc_ctrl_sim:0.1` | **RUNTIME_FAIL** | 0 | 32 | [`runtime/lowrisc_dv_adc_ctrl_sim_0.1/matrix-runtime.log`](latest-unsafe-matrix-logs.tar.gz) |
| runtime | `lowrisc:dv:aes_sim:0.1` | **FAIL** | 3 | 6 | [`runtime/lowrisc_dv_aes_sim_0.1/matrix-compile.log`](latest-unsafe-matrix-logs.tar.gz) |
| runtime | `lowrisc:dv:aon_timer_sim:0.1` | **DEBT** | 0 | 14 | [`runtime/lowrisc_dv_aon_timer_sim_0.1/matrix-runtime.log`](latest-unsafe-matrix-logs.tar.gz) |
| runtime | `lowrisc:dv:chip_sim:0.1` | **FAIL** | 31 | 89 | [`runtime/lowrisc_dv_chip_sim_0.1/matrix-compile.log`](latest-unsafe-matrix-logs.tar.gz) |
| runtime | `lowrisc:dv:clkmgr_sim:0.1` | **FAIL** | 19 | 9 | [`runtime/lowrisc_dv_clkmgr_sim_0.1/matrix-compile.log`](latest-unsafe-matrix-logs.tar.gz) |
| runtime | `lowrisc:dv:csrng_sim:0.1` | **FAIL** | 4 | 29 | [`runtime/lowrisc_dv_csrng_sim_0.1/matrix-compile.log`](latest-unsafe-matrix-logs.tar.gz) |
| runtime | `lowrisc:dv:edn_sim:0.1` | **FAIL** | 3 | 21 | [`runtime/lowrisc_dv_edn_sim_0.1/matrix-compile.log`](latest-unsafe-matrix-logs.tar.gz) |
| runtime | `lowrisc:dv:entropy_src_sim:0.1` | **FAIL** | 4 | 2 | [`runtime/lowrisc_dv_entropy_src_sim_0.1/matrix-compile.log`](latest-unsafe-matrix-logs.tar.gz) |
| runtime | `lowrisc:dv:flash_ctrl_sim:0.1` | **FAIL** | 131 | 0 | [`runtime/lowrisc_dv_flash_ctrl_sim_0.1/matrix-compile.log`](latest-unsafe-matrix-logs.tar.gz) |
| runtime | `lowrisc:dv:gpio_sim:0.1` | **DEBT** | 0 | 13 | [`runtime/lowrisc_dv_gpio_sim_0.1/matrix-runtime.log`](latest-unsafe-matrix-logs.tar.gz) |
| runtime | `lowrisc:dv:hmac_sim:0.1` | **RUNTIME_FAIL** | 0 | 13 | [`runtime/lowrisc_dv_hmac_sim_0.1/matrix-runtime.log`](latest-unsafe-matrix-logs.tar.gz) |
| runtime | `lowrisc:dv:i2c_sim:0.1` | **FAIL** | 18 | 34 | [`runtime/lowrisc_dv_i2c_sim_0.1/matrix-compile.log`](latest-unsafe-matrix-logs.tar.gz) |
| runtime | `lowrisc:dv:ibex_icache_sim:0.1` | **FAIL** | 1 | 0 | [`runtime/lowrisc_dv_ibex_icache_sim_0.1/matrix-compile.log`](latest-unsafe-matrix-logs.tar.gz) |
| runtime | `lowrisc:dv:keymgr_sim:0.1` | **FAIL** | 2 | 0 | [`runtime/lowrisc_dv_keymgr_sim_0.1/matrix-compile.log`](latest-unsafe-matrix-logs.tar.gz) |
| runtime | `lowrisc:dv:kmac_sim:0.1` | **FAIL** | 17 | 3 | [`runtime/lowrisc_dv_kmac_sim_0.1/matrix-compile.log`](latest-unsafe-matrix-logs.tar.gz) |
| runtime | `lowrisc:dv:lc_ctrl_sim:0.1` | **FAIL** | 6 | 20 | [`runtime/lowrisc_dv_lc_ctrl_sim_0.1/matrix-compile.log`](latest-unsafe-matrix-logs.tar.gz) |
| runtime | `lowrisc:dv:otbn_sim:0.1` | **FAIL** | 233 | 33 | [`runtime/lowrisc_dv_otbn_sim_0.1/matrix-compile.log`](latest-unsafe-matrix-logs.tar.gz) |
| runtime | `lowrisc:dv:otp_ctrl_sim:0.1` | **FAIL** | 15 | 83 | [`runtime/lowrisc_dv_otp_ctrl_sim_0.1/matrix-compile.log`](latest-unsafe-matrix-logs.tar.gz) |
| runtime | `lowrisc:dv:pattgen_sim:0.1` | **RUNTIME_FAIL** | 0 | 40 | [`runtime/lowrisc_dv_pattgen_sim_0.1/matrix-runtime.log`](latest-unsafe-matrix-logs.tar.gz) |
| runtime | `lowrisc:dv:prim_alert_sim:0.1` | **DEBT** | 0 | 0 | [`runtime/lowrisc_dv_prim_alert_sim_0.1/matrix-runtime.log`](latest-unsafe-matrix-logs.tar.gz) |
| runtime | `lowrisc:dv:prim_esc_sim:0.1` | **DEBT** | 0 | 0 | [`runtime/lowrisc_dv_prim_esc_sim_0.1/matrix-runtime.log`](latest-unsafe-matrix-logs.tar.gz) |
| runtime | `lowrisc:dv:prim_flop_2sync_sim:0.1` | **FAIL** | 2 | 0 | [`runtime/lowrisc_dv_prim_flop_2sync_sim_0.1/matrix-compile.log`](latest-unsafe-matrix-logs.tar.gz) |
| runtime | `lowrisc:dv:prim_lfsr_sim:0.1` | **FAIL** | 1 | 0 | [`runtime/lowrisc_dv_prim_lfsr_sim_0.1/matrix-compile.log`](latest-unsafe-matrix-logs.tar.gz) |
| runtime | `lowrisc:dv:prim_present_sim:0.1` | **RUNTIME_FAIL** | 0 | 6 | [`runtime/lowrisc_dv_prim_present_sim_0.1/matrix-runtime.log`](latest-unsafe-matrix-logs.tar.gz) |
| runtime | `lowrisc:dv:prim_prince_sim:0.1` | **RUNTIME_FAIL** | 0 | 0 | [`runtime/lowrisc_dv_prim_prince_sim_0.1/matrix-runtime.log`](latest-unsafe-matrix-logs.tar.gz) |
| runtime | `lowrisc:dv:pwm_sim:0.1` | **FAIL** | 8 | 27 | [`runtime/lowrisc_dv_pwm_sim_0.1/matrix-compile.log`](latest-unsafe-matrix-logs.tar.gz) |
| runtime | `lowrisc:dv:pwrmgr_sim:0.1` | **DEBT** | 0 | 14 | [`runtime/lowrisc_dv_pwrmgr_sim_0.1/matrix-runtime.log`](latest-unsafe-matrix-logs.tar.gz) |
| runtime | `lowrisc:dv:rom_ctrl_sim:0.1` | **FAIL** | 1 | 4 | [`runtime/lowrisc_dv_rom_ctrl_sim_0.1/matrix-compile.log`](latest-unsafe-matrix-logs.tar.gz) |
| runtime | `lowrisc:dv:rstmgr_cnsty_chk_sim:0.1` | **FAIL** | 3 | 0 | [`runtime/lowrisc_dv_rstmgr_cnsty_chk_sim_0.1/matrix-compile.log`](latest-unsafe-matrix-logs.tar.gz) |
| runtime | `lowrisc:dv:rstmgr_sim:0.1` | **FAIL** | 11 | 21 | [`runtime/lowrisc_dv_rstmgr_sim_0.1/matrix-compile.log`](latest-unsafe-matrix-logs.tar.gz) |
| runtime | `lowrisc:dv:rv_dm_sim:0.1` | **FAIL** | 3 | 14 | [`runtime/lowrisc_dv_rv_dm_sim_0.1/matrix-compile.log`](latest-unsafe-matrix-logs.tar.gz) |
| runtime | `lowrisc:dv:rv_timer_sim:0.1` | **FAIL** | 5 | 10 | [`runtime/lowrisc_dv_rv_timer_sim_0.1/matrix-compile.log`](latest-unsafe-matrix-logs.tar.gz) |
| runtime | `lowrisc:dv:spi_device_sim:0.1` | **FAIL** | 3 | 71 | [`runtime/lowrisc_dv_spi_device_sim_0.1/matrix-compile.log`](latest-unsafe-matrix-logs.tar.gz) |
| runtime | `lowrisc:dv:spi_host_sim:1.0` | **FAIL** | 2 | 14 | [`runtime/lowrisc_dv_spi_host_sim_1.0/matrix-compile.log`](latest-unsafe-matrix-logs.tar.gz) |
| runtime | `lowrisc:dv:spi_tpm_sim:0.1` | **FAIL** | 3 | 0 | [`runtime/lowrisc_dv_spi_tpm_sim_0.1/matrix-compile.log`](latest-unsafe-matrix-logs.tar.gz) |
| runtime | `lowrisc:dv:spid_jedec_sim:0.1` | **FAIL** | 2 | 0 | [`runtime/lowrisc_dv_spid_jedec_sim_0.1/matrix-compile.log`](latest-unsafe-matrix-logs.tar.gz) |
| runtime | `lowrisc:dv:spid_passthrough_sim:0.1` | **FAIL** | 10 | 1 | [`runtime/lowrisc_dv_spid_passthrough_sim_0.1/matrix-compile.log`](latest-unsafe-matrix-logs.tar.gz) |
| runtime | `lowrisc:dv:spid_readcmd_sim:0.1` | **FAIL** | 2 | 0 | [`runtime/lowrisc_dv_spid_readcmd_sim_0.1/matrix-compile.log`](latest-unsafe-matrix-logs.tar.gz) |
| runtime | `lowrisc:dv:spid_status_sim:0.1` | **FAIL** | 29 | 0 | [`runtime/lowrisc_dv_spid_status_sim_0.1/matrix-compile.log`](latest-unsafe-matrix-logs.tar.gz) |
| runtime | `lowrisc:dv:spid_upload_sim:0.1` | **FAIL** | 4 | 0 | [`runtime/lowrisc_dv_spid_upload_sim_0.1/matrix-compile.log`](latest-unsafe-matrix-logs.tar.gz) |
| runtime | `lowrisc:dv:sram_ctrl_sim:0.1` | **FAIL** | 3 | 5 | [`runtime/lowrisc_dv_sram_ctrl_sim_0.1/matrix-compile.log`](latest-unsafe-matrix-logs.tar.gz) |
| runtime | `lowrisc:dv:sysrst_ctrl_sim:0.1` | **FAIL** | 8 | 4 | [`runtime/lowrisc_dv_sysrst_ctrl_sim_0.1/matrix-compile.log`](latest-unsafe-matrix-logs.tar.gz) |
| runtime | `lowrisc:dv:tl_agent_sim:0.1` | **RUNTIME_TIMEOUT** | 0 | 0 | [`runtime/lowrisc_dv_tl_agent_sim_0.1/matrix-runtime.log`](latest-unsafe-matrix-logs.tar.gz) |
| runtime | `lowrisc:dv:top_earlgrey_xbar_main_sim:0.1` | **DEBT** | 0 | 0 | [`runtime/lowrisc_dv_top_earlgrey_xbar_main_sim_0.1/matrix-runtime.log`](latest-unsafe-matrix-logs.tar.gz) |
| runtime | `lowrisc:dv:top_earlgrey_xbar_peri_sim:0.1` | **DEBT** | 0 | 0 | [`runtime/lowrisc_dv_top_earlgrey_xbar_peri_sim_0.1/matrix-runtime.log`](latest-unsafe-matrix-logs.tar.gz) |
| runtime | `lowrisc:dv:uart_sim:0.1` | **FAIL** | 2 | 0 | [`runtime/lowrisc_dv_uart_sim_0.1/matrix-compile.log`](latest-unsafe-matrix-logs.tar.gz) |
| runtime | `lowrisc:dv:usbdev_sim:0.1` | **FAIL** | 10 | 18 | [`runtime/lowrisc_dv_usbdev_sim_0.1/matrix-compile.log`](latest-unsafe-matrix-logs.tar.gz) |
| runtime | `lowrisc:ip:trial1_sim:0.1` | **RUNTIME_FAIL** | 0 | 3 | [`runtime/lowrisc_ip_trial1_sim_0.1/matrix-runtime.log`](latest-unsafe-matrix-logs.tar.gz) |
| runtime | `lowrisc:opentitan:top_earlgrey_alert_handler_sim:0.1` | **FAIL** | 11 | 83 | [`runtime/lowrisc_opentitan_top_earlgrey_alert_handler_sim_0.1/matrix-compile.log`](latest-unsafe-matrix-logs.tar.gz) |
