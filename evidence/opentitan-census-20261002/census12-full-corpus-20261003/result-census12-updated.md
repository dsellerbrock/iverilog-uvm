# OpenTitan Icarus matrix — updated composite census

- Generated: `2026-10-04T10:15:28+00:00`
- OpenTitan revision: `unknown` (dirty)
- Icarus: `Icarus Verilog version 13.0 (devel) ()`
- Compiler engine SHA-256: `8dae711b38f7229b74b29455db587238ef76452928a66faeb5085aa429ef184c`
- UVM/runtime compile profile: `commercial-unsafe`
- Targets: `49` (initial full matrix plus focused replacements)
- Status counts: `DEBT=1`, `FAIL=0`, `PASS=48`

This is a composite census, not one invocation that reran all 49 targets after the focused fixes. It preserves the original full-matrix result and replaces the OTBN, OTP, Flash, and SPI-TPM rows with later focused retry results. The JSON metadata records those inputs; each row retains its own run metadata.

A `DEBT` row exited successfully but emitted a warning or explicit semantic degradation. It is not a conformance pass.

| Lane | Core | Status | Hard errors | Semantic debt | Evidence log |
|---|---|---:|---:|---:|---|
| runtime | `lowrisc:dv:adc_ctrl_sim:0.1` | **PASS** | 0 | 0 | `/private/tmp/pi/census12/build/runtime/lowrisc_dv_adc_ctrl_sim_0.1/matrix-runtime.log` |
| runtime | `lowrisc:dv:aes_sim:0.1` | **PASS** | 0 | 0 | `/private/tmp/pi/census12/build/runtime/lowrisc_dv_aes_sim_0.1/matrix-runtime.log` |
| runtime | `lowrisc:dv:aon_timer_sim:0.1` | **PASS** | 0 | 0 | `/private/tmp/pi/census12/build/runtime/lowrisc_dv_aon_timer_sim_0.1/matrix-runtime.log` |
| runtime | `lowrisc:dv:chip_sim:0.1` | **PASS** | 0 | 0 | `/private/tmp/pi/census12/build/runtime/lowrisc_dv_chip_sim_0.1/matrix-runtime.log` |
| runtime | `lowrisc:dv:clkmgr_sim:0.1` | **PASS** | 0 | 0 | `/private/tmp/pi/census12/build/runtime/lowrisc_dv_clkmgr_sim_0.1/matrix-runtime.log` |
| runtime | `lowrisc:dv:csrng_sim:0.1` | **PASS** | 0 | 0 | `/private/tmp/pi/census12/build/runtime/lowrisc_dv_csrng_sim_0.1/matrix-runtime.log` |
| runtime | `lowrisc:dv:edn_sim:0.1` | **PASS** | 0 | 0 | `/private/tmp/pi/census12/build/runtime/lowrisc_dv_edn_sim_0.1/matrix-runtime.log` |
| runtime | `lowrisc:dv:entropy_src_sim:0.1` | **PASS** | 0 | 0 | `/private/tmp/pi/census12/build/runtime/lowrisc_dv_entropy_src_sim_0.1/matrix-runtime.log` |
| runtime | `lowrisc:dv:flash_ctrl_sim:0.1` | **DEBT** | 0 | 2 | `/private/tmp/pi/census12/flash-default-five-hour-retry/runtime/lowrisc_dv_flash_ctrl_sim_0.1/matrix-runtime.log` |
| runtime | `lowrisc:dv:gpio_sim:0.1` | **PASS** | 0 | 0 | `/private/tmp/pi/census12/build/runtime/lowrisc_dv_gpio_sim_0.1/matrix-runtime.log` |
| runtime | `lowrisc:dv:hmac_sim:0.1` | **PASS** | 0 | 0 | `/private/tmp/pi/census12/build/runtime/lowrisc_dv_hmac_sim_0.1/matrix-runtime.log` |
| runtime | `lowrisc:dv:i2c_sim:0.1` | **PASS** | 0 | 0 | `/private/tmp/pi/census12/build/runtime/lowrisc_dv_i2c_sim_0.1/matrix-runtime.log` |
| runtime | `lowrisc:dv:ibex_icache_sim:0.1` | **PASS** | 0 | 0 | `/private/tmp/pi/census12/build/runtime/lowrisc_dv_ibex_icache_sim_0.1/matrix-runtime.log` |
| runtime | `lowrisc:dv:keymgr_sim:0.1` | **PASS** | 0 | 0 | `/private/tmp/pi/census12/build/runtime/lowrisc_dv_keymgr_sim_0.1/matrix-runtime.log` |
| runtime | `lowrisc:dv:kmac_sim:0.1` | **PASS** | 0 | 0 | `/private/tmp/pi/census12/build/runtime/lowrisc_dv_kmac_sim_0.1/matrix-runtime.log` |
| runtime | `lowrisc:dv:lc_ctrl_sim:0.1` | **PASS** | 0 | 0 | `/private/tmp/pi/census12/build/runtime/lowrisc_dv_lc_ctrl_sim_0.1/matrix-runtime.log` |
| runtime | `lowrisc:dv:otbn_sim:0.1` | **PASS** | 0 | 0 | `/private/tmp/pi/census12/otbn-xpack-retry/runtime/lowrisc_dv_otbn_sim_0.1/matrix-runtime.log` |
| runtime | `lowrisc:dv:otp_ctrl_sim:0.1` | **PASS** | 0 | 0 | `/private/tmp/pi/census12/targeted-compat/otp/runtime/lowrisc_dv_otp_ctrl_sim_0.1/matrix-runtime.log` |
| runtime | `lowrisc:dv:pattgen_sim:0.1` | **PASS** | 0 | 0 | `/private/tmp/pi/census12/build/runtime/lowrisc_dv_pattgen_sim_0.1/matrix-runtime.log` |
| runtime | `lowrisc:dv:prim_alert_sim:0.1` | **PASS** | 0 | 0 | `/private/tmp/pi/census12/build/runtime/lowrisc_dv_prim_alert_sim_0.1/matrix-runtime.log` |
| runtime | `lowrisc:dv:prim_esc_sim:0.1` | **PASS** | 0 | 0 | `/private/tmp/pi/census12/build/runtime/lowrisc_dv_prim_esc_sim_0.1/matrix-runtime.log` |
| runtime | `lowrisc:dv:prim_flop_2sync_sim:0.1` | **PASS** | 0 | 0 | `/private/tmp/pi/census12/build/runtime/lowrisc_dv_prim_flop_2sync_sim_0.1/matrix-runtime.log` |
| runtime | `lowrisc:dv:prim_lfsr_sim:0.1` | **PASS** | 0 | 0 | `/private/tmp/pi/census12/build/runtime/lowrisc_dv_prim_lfsr_sim_0.1/matrix-runtime.log` |
| runtime | `lowrisc:dv:prim_present_sim:0.1` | **PASS** | 0 | 0 | `/private/tmp/pi/census12/build/runtime/lowrisc_dv_prim_present_sim_0.1/matrix-runtime.log` |
| runtime | `lowrisc:dv:prim_prince_sim:0.1` | **PASS** | 0 | 0 | `/private/tmp/pi/census12/build/runtime/lowrisc_dv_prim_prince_sim_0.1/matrix-runtime.log` |
| runtime | `lowrisc:dv:pwm_sim:0.1` | **PASS** | 0 | 0 | `/private/tmp/pi/census12/build/runtime/lowrisc_dv_pwm_sim_0.1/matrix-runtime.log` |
| runtime | `lowrisc:dv:pwrmgr_sim:0.1` | **PASS** | 0 | 0 | `/private/tmp/pi/census12/build/runtime/lowrisc_dv_pwrmgr_sim_0.1/matrix-runtime.log` |
| runtime | `lowrisc:dv:rom_ctrl_sim:0.1` | **PASS** | 0 | 0 | `/private/tmp/pi/census12/build/runtime/lowrisc_dv_rom_ctrl_sim_0.1/matrix-runtime.log` |
| runtime | `lowrisc:dv:rstmgr_cnsty_chk_sim:0.1` | **PASS** | 0 | 0 | `/private/tmp/pi/census12/build/runtime/lowrisc_dv_rstmgr_cnsty_chk_sim_0.1/matrix-runtime.log` |
| runtime | `lowrisc:dv:rstmgr_sim:0.1` | **PASS** | 0 | 0 | `/private/tmp/pi/census12/build/runtime/lowrisc_dv_rstmgr_sim_0.1/matrix-runtime.log` |
| runtime | `lowrisc:dv:rv_dm_sim:0.1` | **PASS** | 0 | 0 | `/private/tmp/pi/census12/build/runtime/lowrisc_dv_rv_dm_sim_0.1/matrix-runtime.log` |
| runtime | `lowrisc:dv:rv_timer_sim:0.1` | **PASS** | 0 | 0 | `/private/tmp/pi/census12/build/runtime/lowrisc_dv_rv_timer_sim_0.1/matrix-runtime.log` |
| runtime | `lowrisc:dv:spi_device_sim:0.1` | **PASS** | 0 | 0 | `/private/tmp/pi/census12/build/runtime/lowrisc_dv_spi_device_sim_0.1/matrix-runtime.log` |
| runtime | `lowrisc:dv:spi_host_sim:1.0` | **PASS** | 0 | 0 | `/private/tmp/pi/census12/build/runtime/lowrisc_dv_spi_host_sim_1.0/matrix-runtime.log` |
| runtime | `lowrisc:dv:spi_tpm_sim:0.1` | **PASS** | 0 | 0 | `/private/tmp/pi/census12/spi-tpm-final-20261004/runtime/lowrisc_dv_spi_tpm_sim_0.1/matrix-runtime.log` |
| runtime | `lowrisc:dv:spid_jedec_sim:0.1` | **PASS** | 0 | 0 | `/private/tmp/pi/census12/build/runtime/lowrisc_dv_spid_jedec_sim_0.1/matrix-runtime.log` |
| runtime | `lowrisc:dv:spid_passthrough_sim:0.1` | **PASS** | 0 | 0 | `/private/tmp/pi/census12/build/runtime/lowrisc_dv_spid_passthrough_sim_0.1/matrix-runtime.log` |
| runtime | `lowrisc:dv:spid_readcmd_sim:0.1` | **PASS** | 0 | 0 | `/private/tmp/pi/census12/build/runtime/lowrisc_dv_spid_readcmd_sim_0.1/matrix-runtime.log` |
| runtime | `lowrisc:dv:spid_status_sim:0.1` | **PASS** | 0 | 0 | `/private/tmp/pi/census12/build/runtime/lowrisc_dv_spid_status_sim_0.1/matrix-runtime.log` |
| runtime | `lowrisc:dv:spid_upload_sim:0.1` | **PASS** | 0 | 0 | `/private/tmp/pi/census12/build/runtime/lowrisc_dv_spid_upload_sim_0.1/matrix-runtime.log` |
| runtime | `lowrisc:dv:sram_ctrl_sim:0.1` | **PASS** | 0 | 0 | `/private/tmp/pi/census12/build/runtime/lowrisc_dv_sram_ctrl_sim_0.1/matrix-runtime.log` |
| runtime | `lowrisc:dv:sysrst_ctrl_sim:0.1` | **PASS** | 0 | 0 | `/private/tmp/pi/census12/build/runtime/lowrisc_dv_sysrst_ctrl_sim_0.1/matrix-runtime.log` |
| runtime | `lowrisc:dv:tl_agent_sim:0.1` | **PASS** | 0 | 0 | `/private/tmp/pi/census12/build/runtime/lowrisc_dv_tl_agent_sim_0.1/matrix-runtime.log` |
| runtime | `lowrisc:dv:top_earlgrey_xbar_main_sim:0.1` | **PASS** | 0 | 0 | `/private/tmp/pi/census12/build/runtime/lowrisc_dv_top_earlgrey_xbar_main_sim_0.1/matrix-runtime.log` |
| runtime | `lowrisc:dv:top_earlgrey_xbar_peri_sim:0.1` | **PASS** | 0 | 0 | `/private/tmp/pi/census12/build/runtime/lowrisc_dv_top_earlgrey_xbar_peri_sim_0.1/matrix-runtime.log` |
| runtime | `lowrisc:dv:uart_sim:0.1` | **PASS** | 0 | 0 | `/private/tmp/pi/census12/build/runtime/lowrisc_dv_uart_sim_0.1/matrix-runtime.log` |
| runtime | `lowrisc:dv:usbdev_sim:0.1` | **PASS** | 0 | 0 | `/private/tmp/pi/census12/build/runtime/lowrisc_dv_usbdev_sim_0.1/matrix-runtime.log` |
| runtime | `lowrisc:ip:trial1_sim:0.1` | **PASS** | 0 | 0 | `/private/tmp/pi/census12/build/runtime/lowrisc_ip_trial1_sim_0.1/matrix-runtime.log` |
| runtime | `lowrisc:opentitan:top_earlgrey_alert_handler_sim:0.1` | **PASS** | 0 | 0 | `/private/tmp/pi/census12/build/runtime/lowrisc_opentitan_top_earlgrey_alert_handler_sim_0.1/matrix-runtime.log` |

## Focused retry details

- OTBN: PASS in 136.853s using xPack RISC-V assembler/linker; see [`result-otbn-xpack-retry.json`](result-otbn-xpack-retry.json) and its [summary](result-otbn-xpack-retry.md).
- OTP: PASS in 78.783s after the covergroup purity cleanup; zero semantic debt. See [`result-otp-template-cleanup.json`](result-otp-template-cleanup.json), [summary](result-otp-template-cleanup.md), and [`compat-patches/otp-get-offset-covergroup-purity.patch`](compat-patches/otp-get-offset-covergroup-purity.patch).
- Flash: DEBT after 5891.241s under an 18,000s timeout and 9,536 MiB limit; pass banner, zero runtime errors, no timeout, peak physical footprint 1,385,235,896 bytes. Two aggregate `solve before` compile warnings remain. See [`result-flash-five-hour-default.json`](result-flash-five-hour-default.json) and [summary](result-flash-five-hour-default.md).
- SPI-TPM: PASS in 0.378s runtime (0.871s compile), with zero hard errors and zero semantic debt. The core-specific matcher requires both transaction-completion and pass banners with no timeout marker. See [`result-spi-tpm-sram-csb-reset.json`](result-spi-tpm-sram-csb-reset.json), [summary](result-spi-tpm-sram-csb-reset.md), and [`compat-patches/spi-tpm-sram-csb-reset.patch`](compat-patches/spi-tpm-sram-csb-reset.patch).

The preserved initial full-matrix artifacts are [`result-census12.json`](result-census12.json) and [`result-census12.md`](result-census12.md).
