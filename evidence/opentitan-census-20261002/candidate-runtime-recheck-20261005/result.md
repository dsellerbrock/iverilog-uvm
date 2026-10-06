# Candidate OpenTitan runtime matrix

- Generated: `2026-10-05T18:14:41.985835+00:00`
- OpenTitan revision: `unknown` (dirty)
- Icarus: `Icarus Verilog version 13.0 (devel) ()`
- Compiler engine SHA-256: `890c5b3c9ee0098ab4bcf4d25f06b10c3a8758a88d5e867b1a566a5ca9ecfdaa`
- Runtime compile profile: `commercial-unsafe`
- Jobs: `49`
- Status counts: `PASS=49`

| Lane | Core | Status | Runtime seconds | Pass banner | Hard errors | Semantic/runtime debt |
|---|---|---:|---:|---:|---:|---:|
| runtime | `lowrisc:dv:adc_ctrl_sim:0.1` | **PASS** | 251.025 | yes | 0 | 0 |
| runtime | `lowrisc:dv:aes_sim:0.1` | **PASS** | 27.596 | yes | 0 | 0 |
| runtime | `lowrisc:dv:aon_timer_sim:0.1` | **PASS** | 6.123 | yes | 0 | 0 |
| runtime | `lowrisc:dv:chip_sim:0.1` | **PASS** | 243.039 | yes | 0 | 0 |
| runtime | `lowrisc:dv:clkmgr_sim:0.1` | **PASS** | 8.182 | yes | 0 | 0 |
| runtime | `lowrisc:dv:csrng_sim:0.1` | **PASS** | 90.169 | yes | 0 | 0 |
| runtime | `lowrisc:dv:edn_sim:0.1` | **PASS** | 65.391 | yes | 0 | 0 |
| runtime | `lowrisc:dv:entropy_src_sim:0.1` | **PASS** | 27.615 | yes | 0 | 0 |
| runtime | `lowrisc:dv:flash_ctrl_sim:0.1` | **PASS** | 3595.231 | yes | 0 | 0 |
| runtime | `lowrisc:dv:gpio_sim:0.1` | **PASS** | 25.669 | yes | 0 | 0 |
| runtime | `lowrisc:dv:hmac_sim:0.1` | **PASS** | 293.025 | yes | 0 | 0 |
| runtime | `lowrisc:dv:i2c_sim:0.1` | **PASS** | 866.755 | yes | 0 | 0 |
| runtime | `lowrisc:dv:ibex_icache_sim:0.1` | **PASS** | 174.196 | yes | 0 | 0 |
| runtime | `lowrisc:dv:keymgr_sim:0.1` | **PASS** | 58.549 | yes | 0 | 0 |
| runtime | `lowrisc:dv:kmac_sim:0.1` | **PASS** | 360.292 | yes | 0 | 0 |
| runtime | `lowrisc:dv:lc_ctrl_sim:0.1` | **PASS** | 155.059 | yes | 0 | 0 |
| runtime | `lowrisc:dv:otbn_sim:0.1` | **PASS** | 117.071 | yes | 0 | 0 |
| runtime | `lowrisc:dv:otp_ctrl_sim:0.1` | **PASS** | 98.409 | yes | 0 | 0 |
| runtime | `lowrisc:dv:pattgen_sim:0.1` | **PASS** | 19.456 | yes | 0 | 0 |
| runtime | `lowrisc:dv:prim_alert_sim:0.1` | **PASS** | 1.024 | yes | 0 | 0 |
| runtime | `lowrisc:dv:prim_esc_sim:0.1` | **PASS** | 1.024 | yes | 0 | 0 |
| runtime | `lowrisc:dv:prim_flop_2sync_sim:0.1` | **PASS** | 1.024 | yes | 0 | 0 |
| runtime | `lowrisc:dv:prim_lfsr_sim:0.1` | **PASS** | 7.160 | yes | 0 | 0 |
| runtime | `lowrisc:dv:prim_present_sim:0.1` | **PASS** | 3.069 | yes | 0 | 0 |
| runtime | `lowrisc:dv:prim_prince_sim:0.1` | **PASS** | 1.023 | yes | 0 | 0 |
| runtime | `lowrisc:dv:pwm_sim:0.1` | **PASS** | 51.207 | yes | 0 | 0 |
| runtime | `lowrisc:dv:pwrmgr_sim:0.1` | **PASS** | 6.143 | yes | 0 | 0 |
| runtime | `lowrisc:dv:rom_ctrl_sim:0.1` | **PASS** | 209.973 | yes | 0 | 0 |
| runtime | `lowrisc:dv:rstmgr_cnsty_chk_sim:0.1` | **PASS** | 29.734 | yes | 0 | 0 |
| runtime | `lowrisc:dv:rstmgr_sim:0.1` | **PASS** | 29.701 | yes | 0 | 0 |
| runtime | `lowrisc:dv:rv_dm_sim:0.1` | **PASS** | 158.888 | yes | 0 | 0 |
| runtime | `lowrisc:dv:rv_timer_sim:0.1` | **PASS** | 4.095 | yes | 0 | 0 |
| runtime | `lowrisc:dv:spi_device_sim:0.1` | **PASS** | 731.682 | yes | 0 | 0 |
| runtime | `lowrisc:dv:spi_host_sim:1.0` | **PASS** | 1491.628 | yes | 0 | 0 |
| runtime | `lowrisc:dv:spi_tpm_sim:0.1` | **PASS** | 1.021 | yes | 0 | 0 |
| runtime | `lowrisc:dv:spid_jedec_sim:0.1` | **PASS** | 1.022 | yes | 0 | 0 |
| runtime | `lowrisc:dv:spid_passthrough_sim:0.1` | **PASS** | 5.119 | yes | 0 | 0 |
| runtime | `lowrisc:dv:spid_readcmd_sim:0.1` | **PASS** | 1.020 | yes | 0 | 0 |
| runtime | `lowrisc:dv:spid_status_sim:0.1` | **PASS** | 1.026 | yes | 0 | 0 |
| runtime | `lowrisc:dv:spid_upload_sim:0.1` | **PASS** | 12.384 | yes | 0 | 0 |
| runtime | `lowrisc:dv:sram_ctrl_sim:0.1` | **PASS** | 366.153 | yes | 0 | 0 |
| runtime | `lowrisc:dv:sysrst_ctrl_sim:0.1` | **PASS** | 34.841 | yes | 0 | 0 |
| runtime | `lowrisc:dv:tl_agent_sim:0.1` | **PASS** | 152.597 | yes | 0 | 0 |
| runtime | `lowrisc:dv:top_earlgrey_xbar_main_sim:0.1` | **PASS** | 140.608 | yes | 0 | 0 |
| runtime | `lowrisc:dv:top_earlgrey_xbar_peri_sim:0.1` | **PASS** | 48.226 | yes | 0 | 0 |
| runtime | `lowrisc:dv:uart_sim:0.1` | **PASS** | 53.244 | yes | 0 | 0 |
| runtime | `lowrisc:dv:usbdev_sim:0.1` | **PASS** | 16.393 | yes | 0 | 0 |
| runtime | `lowrisc:ip:trial1_sim:0.1` | **PASS** | 1.024 | yes | 0 | 0 |
| runtime | `lowrisc:opentitan:top_earlgrey_alert_handler_sim:0.1` | **PASS** | 574.519 | yes | 0 | 0 |
