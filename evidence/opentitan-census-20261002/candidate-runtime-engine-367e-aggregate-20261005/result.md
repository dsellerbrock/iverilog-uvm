# OpenTitan candidate runtime matrix

- Selected targets: 49 (35 UVM, 14 directed)
- Status counts: PASS 49
- Engine SHA-256: `367e44671b5aabf7786a200c2af4c3dcbd17c449bffa3ea2bc30fbfcfbaa1abc`
- UVM profile: `commercial-unsafe`; workers: 1
- Runtime timeout: 18,000 seconds per target; process memory cap: 9,536 MiB

All rows passed with zero hard errors, semantic/runtime debt, timeouts, memory-limit hits, or monitor errors.

| Lane | Core | Status | Hard errors | Semantic debt | Runtime errors | Runtime debt | Runtime (s) |
|---|---|---:|---:|---:|---:|---:|---:|
| runtime | `lowrisc:dv:adc_ctrl_sim:0.1` | PASS | 0 | 0 | 0 | 0 | 345.549 |
| runtime | `lowrisc:dv:aes_sim:0.1` | PASS | 0 | 0 | 0 | 0 | 31.761 |
| runtime | `lowrisc:dv:aon_timer_sim:0.1` | PASS | 0 | 0 | 0 | 0 | 8.188 |
| runtime | `lowrisc:dv:chip_sim:0.1` | PASS | 0 | 0 | 0 | 0 | 275.702 |
| runtime | `lowrisc:dv:clkmgr_sim:0.1` | PASS | 0 | 0 | 0 | 0 | 9.210 |
| runtime | `lowrisc:dv:csrng_sim:0.1` | PASS | 0 | 0 | 0 | 0 | 88.035 |
| runtime | `lowrisc:dv:edn_sim:0.1` | PASS | 0 | 0 | 0 | 0 | 75.702 |
| runtime | `lowrisc:dv:entropy_src_sim:0.1` | PASS | 0 | 0 | 0 | 0 | 32.787 |
| runtime | `lowrisc:dv:flash_ctrl_sim:0.1` | PASS | 0 | 0 | 0 | 0 | 3779.271 |
| runtime | `lowrisc:dv:gpio_sim:0.1` | PASS | 0 | 0 | 0 | 0 | 18.425 |
| runtime | `lowrisc:dv:hmac_sim:0.1` | PASS | 0 | 0 | 0 | 0 | 258.954 |
| runtime | `lowrisc:dv:i2c_sim:0.1` | PASS | 0 | 0 | 0 | 0 | 1134.878 |
| runtime | `lowrisc:dv:ibex_icache_sim:0.1` | PASS | 0 | 0 | 0 | 0 | 160.740 |
| runtime | `lowrisc:dv:keymgr_sim:0.1` | PASS | 0 | 0 | 0 | 0 | 42.997 |
| runtime | `lowrisc:dv:kmac_sim:0.1` | PASS | 0 | 0 | 0 | 0 | 274.385 |
| runtime | `lowrisc:dv:lc_ctrl_sim:0.1` | PASS | 0 | 0 | 0 | 0 | 112.576 |
| runtime | `lowrisc:dv:otbn_sim:0.1` | PASS | 0 | 0 | 0 | 0 | 108.780 |
| runtime | `lowrisc:dv:otp_ctrl_sim:0.1` | PASS | 0 | 0 | 0 | 0 | 91.183 |
| runtime | `lowrisc:dv:pattgen_sim:0.1` | PASS | 0 | 0 | 0 | 0 | 19.444 |
| runtime | `lowrisc:dv:prim_alert_sim:0.1` | PASS | 0 | 0 | 0 | 0 | 1.023 |
| runtime | `lowrisc:dv:prim_esc_sim:0.1` | PASS | 0 | 0 | 0 | 0 | 1.023 |
| runtime | `lowrisc:dv:prim_flop_2sync_sim:0.1` | PASS | 0 | 0 | 0 | 0 | 1.023 |
| runtime | `lowrisc:dv:prim_lfsr_sim:0.1` | PASS | 0 | 0 | 0 | 0 | 7.156 |
| runtime | `lowrisc:dv:prim_present_sim:0.1` | PASS | 0 | 0 | 0 | 0 | 3.067 |
| runtime | `lowrisc:dv:prim_prince_sim:0.1` | PASS | 0 | 0 | 0 | 0 | 1.023 |
| runtime | `lowrisc:dv:pwm_sim:0.1` | PASS | 0 | 0 | 0 | 0 | 46.071 |
| runtime | `lowrisc:dv:pwrmgr_sim:0.1` | PASS | 0 | 0 | 0 | 0 | 8.220 |
| runtime | `lowrisc:dv:rom_ctrl_sim:0.1` | PASS | 0 | 0 | 0 | 0 | 233.733 |
| runtime | `lowrisc:dv:rstmgr_cnsty_chk_sim:0.1` | PASS | 0 | 0 | 0 | 0 | 31.836 |
| runtime | `lowrisc:dv:rstmgr_sim:0.1` | PASS | 0 | 0 | 0 | 0 | 26.587 |
| runtime | `lowrisc:dv:rv_dm_sim:0.1` | PASS | 0 | 0 | 0 | 0 | 140.246 |
| runtime | `lowrisc:dv:rv_timer_sim:0.1` | PASS | 0 | 0 | 0 | 0 | 4.093 |
| runtime | `lowrisc:dv:spi_device_sim:0.1` | PASS | 0 | 0 | 0 | 0 | 602.845 |
| runtime | `lowrisc:dv:spi_host_sim:1.0` | PASS | 0 | 0 | 0 | 0 | 1362.650 |
| runtime | `lowrisc:dv:spi_tpm_sim:0.1` | PASS | 0 | 0 | 0 | 0 | 1.023 |
| runtime | `lowrisc:dv:spid_jedec_sim:0.1` | PASS | 0 | 0 | 0 | 0 | 1.024 |
| runtime | `lowrisc:dv:spid_passthrough_sim:0.1` | PASS | 0 | 0 | 0 | 0 | 6.188 |
| runtime | `lowrisc:dv:spid_readcmd_sim:0.1` | PASS | 0 | 0 | 0 | 0 | 2.062 |
| runtime | `lowrisc:dv:spid_status_sim:0.1` | PASS | 0 | 0 | 0 | 0 | 1.029 |
| runtime | `lowrisc:dv:spid_upload_sim:0.1` | PASS | 0 | 0 | 0 | 0 | 5.135 |
| runtime | `lowrisc:dv:sram_ctrl_sim:0.1` | PASS | 0 | 0 | 0 | 0 | 380.991 |
| runtime | `lowrisc:dv:sysrst_ctrl_sim:0.1` | PASS | 0 | 0 | 0 | 0 | 36.889 |
| runtime | `lowrisc:dv:tl_agent_sim:0.1` | PASS | 0 | 0 | 0 | 0 | 183.510 |
| runtime | `lowrisc:dv:top_earlgrey_xbar_main_sim:0.1` | PASS | 0 | 0 | 0 | 0 | 184.143 |
| runtime | `lowrisc:dv:top_earlgrey_xbar_peri_sim:0.1` | PASS | 0 | 0 | 0 | 0 | 49.168 |
| runtime | `lowrisc:dv:uart_sim:0.1` | PASS | 0 | 0 | 0 | 0 | 49.094 |
| runtime | `lowrisc:dv:usbdev_sim:0.1` | PASS | 0 | 0 | 0 | 0 | 15.350 |
| runtime | `lowrisc:ip:trial1_sim:0.1` | PASS | 0 | 0 | 0 | 0 | 1.023 |
| runtime | `lowrisc:opentitan:top_earlgrey_alert_handler_sim:0.1` | PASS | 0 | 0 | 0 | 0 | 977.340 |
