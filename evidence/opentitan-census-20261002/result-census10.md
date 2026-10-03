# OpenTitan Icarus matrix

- Generated: `2026-10-02T20:40:56.055255+00:00`
- OpenTitan revision: `a78922f14a8cc20c7ee569f322a04626f2ac6127` (dirty)
- Icarus: `Icarus Verilog version 13.0 (devel) ()`
- Compiler engine SHA-256: `6a18cb3c8c4da86ad3e230935d8085635ea015e9fbf24eb4f6e07a8fd6ed384b`
- UVM/runtime compile profile: `commercial-unsafe`
- Jobs: `125`
- Status counts: `DEBT=8`, `DEPENDENCY_ONLY=81`, `FAIL=5`, `PASS=25`, `SETUP_FAIL=3`, `UPSTREAM_INVALID=3`

A `DEBT` result exited successfully but emitted a warning or explicit semantic degradation. It is not a conformance pass.

| Lane | Core | Status | Hard errors | Semantic debt | Log |
|---|---|---:|---:|---:|---|
| rtl | `lowrisc:ibex:bus_params_pkg:0` | **DEPENDENCY_ONLY** | 0 | 0 | `/private/tmp/pi/census10/build/rtl/lowrisc_ibex_bus_params_pkg_0/matrix-setup.log` |
| rtl | `lowrisc:ibex:ibex_core:0.1` | **DEBT** | 0 | 0 | `/private/tmp/pi/census10/build/rtl/lowrisc_ibex_ibex_core_0.1/matrix-compile.log` |
| rtl | `lowrisc:ibex:ibex_icache:0.1` | **PASS** | 0 | 0 | `/private/tmp/pi/census10/build/rtl/lowrisc_ibex_ibex_icache_0.1/matrix-compile.log` |
| rtl | `lowrisc:ibex:ibex_multdiv:0.1` | **DEPENDENCY_ONLY** | 0 | 0 | `/private/tmp/pi/census10/build/rtl/lowrisc_ibex_ibex_multdiv_0.1/matrix-setup.log` |
| rtl | `lowrisc:ibex:ibex_pkg:0.1` | **DEPENDENCY_ONLY** | 0 | 0 | `/private/tmp/pi/census10/build/rtl/lowrisc_ibex_ibex_pkg_0.1/matrix-setup.log` |
| rtl | `lowrisc:ibex:ibex_riscv_compliance:0.1` | **SETUP_FAIL** | 0 | 0 | `/private/tmp/pi/census10/build/rtl/lowrisc_ibex_ibex_riscv_compliance_0.1/matrix-setup.log` |
| rtl | `lowrisc:ibex:ibex_simple_system_cosim:0` | **UPSTREAM_INVALID** | 0 | 0 | `/private/tmp/pi/census10/build/rtl/lowrisc_ibex_ibex_simple_system_cosim_0/matrix-setup.log` |
| rtl | `lowrisc:ibex:ibex_top:0.1` | **DEBT** | 0 | 0 | `/private/tmp/pi/census10/build/rtl/lowrisc_ibex_ibex_top_0.1/matrix-compile.log` |
| rtl | `lowrisc:ibex:ibex_tracer:0.1` | **DEPENDENCY_ONLY** | 0 | 0 | `/private/tmp/pi/census10/build/rtl/lowrisc_ibex_ibex_tracer_0.1/matrix-setup.log` |
| rtl | `lowrisc:ibex:tb_cs_registers:0` | **SETUP_FAIL** | 0 | 0 | `/private/tmp/pi/census10/build/rtl/lowrisc_ibex_tb_cs_registers_0/matrix-setup.log` |
| rtl | `lowrisc:ip:adc_ctrl:1.0` | **PASS** | 0 | 0 | `/private/tmp/pi/census10/build/rtl/lowrisc_ip_adc_ctrl_1.0/matrix-compile.log` |
| rtl | `lowrisc:ip:aes:1.0` | **PASS** | 0 | 0 | `/private/tmp/pi/census10/build/rtl/lowrisc_ip_aes_1.0/matrix-compile.log` |
| rtl | `lowrisc:ip:aes_wrap:1.0` | **UPSTREAM_INVALID** | 2 | 1 | `/private/tmp/pi/census10/build/rtl/lowrisc_ip_aes_wrap_1.0/matrix-compile.log` |
| rtl | `lowrisc:ip:alert_handler_component:0.1` | **DEPENDENCY_ONLY** | 0 | 0 | `/private/tmp/pi/census10/build/rtl/lowrisc_ip_alert_handler_component_0.1/matrix-setup.log` |
| rtl | `lowrisc:ip:aon_timer:0.1` | **PASS** | 0 | 0 | `/private/tmp/pi/census10/build/rtl/lowrisc_ip_aon_timer_0.1/matrix-compile.log` |
| rtl | `lowrisc:ip:ascon:0.1` | **PASS** | 0 | 0 | `/private/tmp/pi/census10/build/rtl/lowrisc_ip_ascon_0.1/matrix-compile.log` |
| rtl | `lowrisc:ip:csrng:0.1` | **PASS** | 0 | 0 | `/private/tmp/pi/census10/build/rtl/lowrisc_ip_csrng_0.1/matrix-compile.log` |
| rtl | `lowrisc:ip:csrng_pkg:0.1` | **DEPENDENCY_ONLY** | 0 | 0 | `/private/tmp/pi/census10/build/rtl/lowrisc_ip_csrng_pkg_0.1/matrix-setup.log` |
| rtl | `lowrisc:ip:edn:0.1` | **PASS** | 0 | 0 | `/private/tmp/pi/census10/build/rtl/lowrisc_ip_edn_0.1/matrix-compile.log` |
| rtl | `lowrisc:ip:edn_pkg:0.1` | **DEPENDENCY_ONLY** | 0 | 0 | `/private/tmp/pi/census10/build/rtl/lowrisc_ip_edn_pkg_0.1/matrix-setup.log` |
| rtl | `lowrisc:ip:entropy_src:0.1` | **PASS** | 0 | 0 | `/private/tmp/pi/census10/build/rtl/lowrisc_ip_entropy_src_0.1/matrix-compile.log` |
| rtl | `lowrisc:ip:entropy_src_ack_sm_pkg:0.1` | **DEPENDENCY_ONLY** | 0 | 0 | `/private/tmp/pi/census10/build/rtl/lowrisc_ip_entropy_src_ack_sm_pkg_0.1/matrix-setup.log` |
| rtl | `lowrisc:ip:entropy_src_main_sm_pkg:0.1` | **DEPENDENCY_ONLY** | 0 | 0 | `/private/tmp/pi/census10/build/rtl/lowrisc_ip_entropy_src_main_sm_pkg_0.1/matrix-setup.log` |
| rtl | `lowrisc:ip:entropy_src_pkg:0.1` | **DEPENDENCY_ONLY** | 0 | 0 | `/private/tmp/pi/census10/build/rtl/lowrisc_ip_entropy_src_pkg_0.1/matrix-setup.log` |
| rtl | `lowrisc:ip:flash_ctrl_prim_reg_top:1.0` | **FAIL** | 1 | 0 | `/private/tmp/pi/census10/build/rtl/lowrisc_ip_flash_ctrl_prim_reg_top_1.0/matrix-compile.log` |
| rtl | `lowrisc:ip:gpio:0.1` | **PASS** | 0 | 0 | `/private/tmp/pi/census10/build/rtl/lowrisc_ip_gpio_0.1/matrix-compile.log` |
| rtl | `lowrisc:ip:hmac:0.1` | **PASS** | 0 | 0 | `/private/tmp/pi/census10/build/rtl/lowrisc_ip_hmac_0.1/matrix-compile.log` |
| rtl | `lowrisc:ip:i2c:0.1` | **DEBT** | 0 | 1 | `/private/tmp/pi/census10/build/rtl/lowrisc_ip_i2c_0.1/matrix-compile.log` |
| rtl | `lowrisc:ip:i2c_pkg:0.1` | **DEPENDENCY_ONLY** | 0 | 0 | `/private/tmp/pi/census10/build/rtl/lowrisc_ip_i2c_pkg_0.1/matrix-setup.log` |
| rtl | `lowrisc:ip:jtag_pkg:0.1` | **DEPENDENCY_ONLY** | 0 | 0 | `/private/tmp/pi/census10/build/rtl/lowrisc_ip_jtag_pkg_0.1/matrix-setup.log` |
| rtl | `lowrisc:ip:keymgr:0.1` | **PASS** | 0 | 0 | `/private/tmp/pi/census10/build/rtl/lowrisc_ip_keymgr_0.1/matrix-compile.log` |
| rtl | `lowrisc:ip:keymgr_pkg:0.1` | **DEPENDENCY_ONLY** | 0 | 0 | `/private/tmp/pi/census10/build/rtl/lowrisc_ip_keymgr_pkg_0.1/matrix-setup.log` |
| rtl | `lowrisc:ip:kmac:0.1` | **PASS** | 0 | 0 | `/private/tmp/pi/census10/build/rtl/lowrisc_ip_kmac_0.1/matrix-compile.log` |
| rtl | `lowrisc:ip:kmac_pkg:0.1` | **DEPENDENCY_ONLY** | 0 | 0 | `/private/tmp/pi/census10/build/rtl/lowrisc_ip_kmac_pkg_0.1/matrix-setup.log` |
| rtl | `lowrisc:ip:kmac_reduced:0.1` | **PASS** | 0 | 0 | `/private/tmp/pi/census10/build/rtl/lowrisc_ip_kmac_reduced_0.1/matrix-compile.log` |
| rtl | `lowrisc:ip:lc_ctrl:0.1` | **PASS** | 0 | 0 | `/private/tmp/pi/census10/build/rtl/lowrisc_ip_lc_ctrl_0.1/matrix-compile.log` |
| rtl | `lowrisc:ip:lc_ctrl_pkg:0.1` | **FAIL** | 8 | 0 | `/private/tmp/pi/census10/build/rtl/lowrisc_ip_lc_ctrl_pkg_0.1/matrix-compile.log` |
| rtl | `lowrisc:ip:lc_ctrl_state_pkg:0.1` | **DEPENDENCY_ONLY** | 0 | 0 | `/private/tmp/pi/census10/build/rtl/lowrisc_ip_lc_ctrl_state_pkg_0.1/matrix-setup.log` |
| rtl | `lowrisc:ip:otbn_pkg:0.1` | **DEPENDENCY_ONLY** | 0 | 0 | `/private/tmp/pi/census10/build/rtl/lowrisc_ip_otbn_pkg_0.1/matrix-setup.log` |
| rtl | `lowrisc:ip:otbn_tracer:0` | **DEPENDENCY_ONLY** | 0 | 0 | `/private/tmp/pi/census10/build/rtl/lowrisc_ip_otbn_tracer_0/matrix-setup.log` |
| rtl | `lowrisc:ip:otp_ctrl:1.0` | **DEBT** | 0 | 1 | `/private/tmp/pi/census10/build/rtl/lowrisc_ip_otp_ctrl_1.0/matrix-compile.log` |
| rtl | `lowrisc:ip:otp_ctrl_pkg:1.0` | **FAIL** | 8 | 0 | `/private/tmp/pi/census10/build/rtl/lowrisc_ip_otp_ctrl_pkg_1.0/matrix-compile.log` |
| rtl | `lowrisc:ip:otp_ctrl_prim_reg_top:1.0` | **FAIL** | 43 | 0 | `/private/tmp/pi/census10/build/rtl/lowrisc_ip_otp_ctrl_prim_reg_top_1.0/matrix-compile.log` |
| rtl | `lowrisc:ip:pattgen:0.1` | **PASS** | 0 | 0 | `/private/tmp/pi/census10/build/rtl/lowrisc_ip_pattgen_0.1/matrix-compile.log` |
| rtl | `lowrisc:ip:pinmux:0.1` | **PASS** | 0 | 0 | `/private/tmp/pi/census10/build/rtl/lowrisc_ip_pinmux_0.1/matrix-compile.log` |
| rtl | `lowrisc:ip:pinmux_component:0.1` | **DEPENDENCY_ONLY** | 0 | 0 | `/private/tmp/pi/census10/build/rtl/lowrisc_ip_pinmux_component_0.1/matrix-setup.log` |
| rtl | `lowrisc:ip:pinmux_reg:0.1` | **DEPENDENCY_ONLY** | 0 | 0 | `/private/tmp/pi/census10/build/rtl/lowrisc_ip_pinmux_reg_0.1/matrix-setup.log` |
| rtl | `lowrisc:ip:pwm:0.1` | **PASS** | 0 | 0 | `/private/tmp/pi/census10/build/rtl/lowrisc_ip_pwm_0.1/matrix-compile.log` |
| rtl | `lowrisc:ip:pwrmgr_component:0.1` | **PASS** | 0 | 0 | `/private/tmp/pi/census10/build/rtl/lowrisc_ip_pwrmgr_component_0.1/matrix-compile.log` |
| rtl | `lowrisc:ip:rom_ctrl:0.1` | **DEBT** | 0 | 1 | `/private/tmp/pi/census10/build/rtl/lowrisc_ip_rom_ctrl_0.1/matrix-compile.log` |
| rtl | `lowrisc:ip:rom_ctrl_pkg:0.1` | **DEPENDENCY_ONLY** | 0 | 0 | `/private/tmp/pi/census10/build/rtl/lowrisc_ip_rom_ctrl_pkg_0.1/matrix-setup.log` |
| rtl | `lowrisc:ip:rstmgr_cnsty_chk:0` | **DEPENDENCY_ONLY** | 0 | 0 | `/private/tmp/pi/census10/build/rtl/lowrisc_ip_rstmgr_cnsty_chk_0/matrix-setup.log` |
| rtl | `lowrisc:ip:rv_core_ibex:0.1` | **DEBT** | 0 | 1 | `/private/tmp/pi/census10/build/rtl/lowrisc_ip_rv_core_ibex_0.1/matrix-compile.log` |
| rtl | `lowrisc:ip:rv_core_ibex_pkg:0.1` | **DEPENDENCY_ONLY** | 0 | 0 | `/private/tmp/pi/census10/build/rtl/lowrisc_ip_rv_core_ibex_pkg_0.1/matrix-setup.log` |
| rtl | `lowrisc:ip:rv_dm:0.1` | **PASS** | 0 | 0 | `/private/tmp/pi/census10/build/rtl/lowrisc_ip_rv_dm_0.1/matrix-compile.log` |
| rtl | `lowrisc:ip:rv_plic_component:0.1` | **DEPENDENCY_ONLY** | 0 | 0 | `/private/tmp/pi/census10/build/rtl/lowrisc_ip_rv_plic_component_0.1/matrix-setup.log` |
| rtl | `lowrisc:ip:rv_timer:0.1` | **PASS** | 0 | 0 | `/private/tmp/pi/census10/build/rtl/lowrisc_ip_rv_timer_0.1/matrix-compile.log` |
| rtl | `lowrisc:ip:sha3:0.1` | **PASS** | 0 | 0 | `/private/tmp/pi/census10/build/rtl/lowrisc_ip_sha3_0.1/matrix-compile.log` |
| rtl | `lowrisc:ip:spi_device:0.1` | **FAIL** | 1 | 37 | `/private/tmp/pi/census10/build/rtl/lowrisc_ip_spi_device_0.1/matrix-compile.log` |
| rtl | `lowrisc:ip:spi_device_pkg:0.1` | **DEPENDENCY_ONLY** | 0 | 0 | `/private/tmp/pi/census10/build/rtl/lowrisc_ip_spi_device_pkg_0.1/matrix-setup.log` |
| rtl | `lowrisc:ip:spi_host:1.0` | **PASS** | 0 | 0 | `/private/tmp/pi/census10/build/rtl/lowrisc_ip_spi_host_1.0/matrix-compile.log` |
| rtl | `lowrisc:ip:sram_ctrl:0.1` | **DEBT** | 0 | 1 | `/private/tmp/pi/census10/build/rtl/lowrisc_ip_sram_ctrl_0.1/matrix-compile.log` |
| rtl | `lowrisc:ip:sram_ctrl_pkg:0.1` | **DEPENDENCY_ONLY** | 0 | 0 | `/private/tmp/pi/census10/build/rtl/lowrisc_ip_sram_ctrl_pkg_0.1/matrix-setup.log` |
| rtl | `lowrisc:ip:sysrst_ctrl:1.0` | **PASS** | 0 | 0 | `/private/tmp/pi/census10/build/rtl/lowrisc_ip_sysrst_ctrl_1.0/matrix-compile.log` |
| rtl | `lowrisc:ip:tlul:0.1` | **DEPENDENCY_ONLY** | 0 | 0 | `/private/tmp/pi/census10/build/rtl/lowrisc_ip_tlul_0.1/matrix-setup.log` |
| rtl | `lowrisc:ip:uart:0.1` | **PASS** | 0 | 0 | `/private/tmp/pi/census10/build/rtl/lowrisc_ip_uart_0.1/matrix-compile.log` |
| rtl | `lowrisc:ip:usb_fs_nb_pe:0.1` | **PASS** | 0 | 0 | `/private/tmp/pi/census10/build/rtl/lowrisc_ip_usb_fs_nb_pe_0.1/matrix-compile.log` |
| rtl | `lowrisc:ip:usbdev:0.1` | **DEBT** | 0 | 1 | `/private/tmp/pi/census10/build/rtl/lowrisc_ip_usbdev_0.1/matrix-compile.log` |
| rtl | `lowrisc:ip:usbdev_pkg:0.1` | **DEPENDENCY_ONLY** | 0 | 0 | `/private/tmp/pi/census10/build/rtl/lowrisc_ip_usbdev_pkg_0.1/matrix-setup.log` |
| rtl | `lowrisc:prim:alert:0` | **DEPENDENCY_ONLY** | 0 | 0 | `/private/tmp/pi/census10/build/rtl/lowrisc_prim_alert_0/matrix-setup.log` |
| rtl | `lowrisc:prim:all:0.1` | **DEPENDENCY_ONLY** | 0 | 0 | `/private/tmp/pi/census10/build/rtl/lowrisc_prim_all_0.1/matrix-setup.log` |
| rtl | `lowrisc:prim:and2:0` | **DEPENDENCY_ONLY** | 0 | 0 | `/private/tmp/pi/census10/build/rtl/lowrisc_prim_and2_0/matrix-setup.log` |
| rtl | `lowrisc:prim:arbiter:0` | **DEPENDENCY_ONLY** | 0 | 0 | `/private/tmp/pi/census10/build/rtl/lowrisc_prim_arbiter_0/matrix-setup.log` |
| rtl | `lowrisc:prim:assert:0.1` | **DEPENDENCY_ONLY** | 0 | 0 | `/private/tmp/pi/census10/build/rtl/lowrisc_prim_assert_0.1/matrix-setup.log` |
| rtl | `lowrisc:prim:blanker:0` | **DEPENDENCY_ONLY** | 0 | 0 | `/private/tmp/pi/census10/build/rtl/lowrisc_prim_blanker_0/matrix-setup.log` |
| rtl | `lowrisc:prim:buf:0` | **DEPENDENCY_ONLY** | 0 | 0 | `/private/tmp/pi/census10/build/rtl/lowrisc_prim_buf_0/matrix-setup.log` |
| rtl | `lowrisc:prim:cdc_rand_delay:0` | **DEPENDENCY_ONLY** | 0 | 0 | `/private/tmp/pi/census10/build/rtl/lowrisc_prim_cdc_rand_delay_0/matrix-setup.log` |
| rtl | `lowrisc:prim:cipher:0` | **DEPENDENCY_ONLY** | 0 | 0 | `/private/tmp/pi/census10/build/rtl/lowrisc_prim_cipher_0/matrix-setup.log` |
| rtl | `lowrisc:prim:cipher_pkg:0.1` | **DEPENDENCY_ONLY** | 0 | 0 | `/private/tmp/pi/census10/build/rtl/lowrisc_prim_cipher_pkg_0.1/matrix-setup.log` |
| rtl | `lowrisc:prim:clock_buf:0` | **DEPENDENCY_ONLY** | 0 | 0 | `/private/tmp/pi/census10/build/rtl/lowrisc_prim_clock_buf_0/matrix-setup.log` |
| rtl | `lowrisc:prim:clock_div:0` | **DEPENDENCY_ONLY** | 0 | 0 | `/private/tmp/pi/census10/build/rtl/lowrisc_prim_clock_div_0/matrix-setup.log` |
| rtl | `lowrisc:prim:clock_gating:0` | **DEPENDENCY_ONLY** | 0 | 0 | `/private/tmp/pi/census10/build/rtl/lowrisc_prim_clock_gating_0/matrix-setup.log` |
| rtl | `lowrisc:prim:clock_gp_mux2:0` | **DEPENDENCY_ONLY** | 0 | 0 | `/private/tmp/pi/census10/build/rtl/lowrisc_prim_clock_gp_mux2_0/matrix-setup.log` |
| rtl | `lowrisc:prim:clock_inv:0` | **DEPENDENCY_ONLY** | 0 | 0 | `/private/tmp/pi/census10/build/rtl/lowrisc_prim_clock_inv_0/matrix-setup.log` |
| rtl | `lowrisc:prim:clock_mux2:0` | **DEPENDENCY_ONLY** | 0 | 0 | `/private/tmp/pi/census10/build/rtl/lowrisc_prim_clock_mux2_0/matrix-setup.log` |
| rtl | `lowrisc:prim:count:0` | **DEPENDENCY_ONLY** | 0 | 0 | `/private/tmp/pi/census10/build/rtl/lowrisc_prim_count_0/matrix-setup.log` |
| rtl | `lowrisc:prim:crc32:0` | **DEPENDENCY_ONLY** | 0 | 0 | `/private/tmp/pi/census10/build/rtl/lowrisc_prim_crc32_0/matrix-setup.log` |
| rtl | `lowrisc:prim:diff_decode:0` | **DEPENDENCY_ONLY** | 0 | 0 | `/private/tmp/pi/census10/build/rtl/lowrisc_prim_diff_decode_0/matrix-setup.log` |
| rtl | `lowrisc:prim:double_lfsr:0` | **DEPENDENCY_ONLY** | 0 | 0 | `/private/tmp/pi/census10/build/rtl/lowrisc_prim_double_lfsr_0/matrix-setup.log` |
| rtl | `lowrisc:prim:edge_detector:0.1` | **DEPENDENCY_ONLY** | 0 | 0 | `/private/tmp/pi/census10/build/rtl/lowrisc_prim_edge_detector_0.1/matrix-setup.log` |
| rtl | `lowrisc:prim:edn_req:0.1` | **DEPENDENCY_ONLY** | 0 | 0 | `/private/tmp/pi/census10/build/rtl/lowrisc_prim_edn_req_0.1/matrix-setup.log` |
| rtl | `lowrisc:prim:esc:0` | **DEPENDENCY_ONLY** | 0 | 0 | `/private/tmp/pi/census10/build/rtl/lowrisc_prim_esc_0/matrix-setup.log` |
| rtl | `lowrisc:prim:fifo:0` | **DEPENDENCY_ONLY** | 0 | 0 | `/private/tmp/pi/census10/build/rtl/lowrisc_prim_fifo_0/matrix-setup.log` |
| rtl | `lowrisc:prim:flash:0` | **DEPENDENCY_ONLY** | 0 | 0 | `/private/tmp/pi/census10/build/rtl/lowrisc_prim_flash_0/matrix-setup.log` |
| rtl | `lowrisc:prim:flop:0` | **DEPENDENCY_ONLY** | 0 | 0 | `/private/tmp/pi/census10/build/rtl/lowrisc_prim_flop_0/matrix-setup.log` |
| rtl | `lowrisc:prim:flop_2sync:0` | **DEPENDENCY_ONLY** | 0 | 0 | `/private/tmp/pi/census10/build/rtl/lowrisc_prim_flop_2sync_0/matrix-setup.log` |
| rtl | `lowrisc:prim:flop_en:0` | **DEPENDENCY_ONLY** | 0 | 0 | `/private/tmp/pi/census10/build/rtl/lowrisc_prim_flop_en_0/matrix-setup.log` |
| rtl | `lowrisc:prim:gf_mult:0` | **DEPENDENCY_ONLY** | 0 | 0 | `/private/tmp/pi/census10/build/rtl/lowrisc_prim_gf_mult_0/matrix-setup.log` |
| rtl | `lowrisc:prim:lc_and_hardened:0.1` | **DEPENDENCY_ONLY** | 0 | 0 | `/private/tmp/pi/census10/build/rtl/lowrisc_prim_lc_and_hardened_0.1/matrix-setup.log` |
| rtl | `lowrisc:prim:lc_combine:0.1` | **DEPENDENCY_ONLY** | 0 | 0 | `/private/tmp/pi/census10/build/rtl/lowrisc_prim_lc_combine_0.1/matrix-setup.log` |
| rtl | `lowrisc:prim:lc_dec:0.1` | **DEPENDENCY_ONLY** | 0 | 0 | `/private/tmp/pi/census10/build/rtl/lowrisc_prim_lc_dec_0.1/matrix-setup.log` |
| rtl | `lowrisc:prim:lc_or_hardened:0.1` | **DEPENDENCY_ONLY** | 0 | 0 | `/private/tmp/pi/census10/build/rtl/lowrisc_prim_lc_or_hardened_0.1/matrix-setup.log` |
| rtl | `lowrisc:prim:lc_sender:0.1` | **DEPENDENCY_ONLY** | 0 | 0 | `/private/tmp/pi/census10/build/rtl/lowrisc_prim_lc_sender_0.1/matrix-setup.log` |
| rtl | `lowrisc:prim:lc_sync:0.1` | **DEPENDENCY_ONLY** | 0 | 0 | `/private/tmp/pi/census10/build/rtl/lowrisc_prim_lc_sync_0.1/matrix-setup.log` |
| rtl | `lowrisc:prim:lfsr:0.1` | **DEPENDENCY_ONLY** | 0 | 0 | `/private/tmp/pi/census10/build/rtl/lowrisc_prim_lfsr_0.1/matrix-setup.log` |
| rtl | `lowrisc:prim:macros:0.1` | **DEPENDENCY_ONLY** | 0 | 0 | `/private/tmp/pi/census10/build/rtl/lowrisc_prim_macros_0.1/matrix-setup.log` |
| rtl | `lowrisc:prim:max_tree:0` | **DEPENDENCY_ONLY** | 0 | 0 | `/private/tmp/pi/census10/build/rtl/lowrisc_prim_max_tree_0/matrix-setup.log` |
| rtl | `lowrisc:prim:measure:0` | **DEPENDENCY_ONLY** | 0 | 0 | `/private/tmp/pi/census10/build/rtl/lowrisc_prim_measure_0/matrix-setup.log` |
| rtl | `lowrisc:prim:msb_extend:0` | **DEPENDENCY_ONLY** | 0 | 0 | `/private/tmp/pi/census10/build/rtl/lowrisc_prim_msb_extend_0/matrix-setup.log` |
| rtl | `lowrisc:prim:mubi:0.1` | **DEPENDENCY_ONLY** | 0 | 0 | `/private/tmp/pi/census10/build/rtl/lowrisc_prim_mubi_0.1/matrix-setup.log` |
| rtl | `lowrisc:prim:multibit_sync:0.1` | **DEPENDENCY_ONLY** | 0 | 0 | `/private/tmp/pi/census10/build/rtl/lowrisc_prim_multibit_sync_0.1/matrix-setup.log` |
| rtl | `lowrisc:prim:onehot:0` | **DEPENDENCY_ONLY** | 0 | 0 | `/private/tmp/pi/census10/build/rtl/lowrisc_prim_onehot_0/matrix-setup.log` |
| rtl | `lowrisc:prim:onehot_check:0` | **DEPENDENCY_ONLY** | 0 | 0 | `/private/tmp/pi/census10/build/rtl/lowrisc_prim_onehot_check_0/matrix-setup.log` |
| rtl | `lowrisc:prim:otp:0` | **DEPENDENCY_ONLY** | 0 | 0 | `/private/tmp/pi/census10/build/rtl/lowrisc_prim_otp_0/matrix-setup.log` |
| rtl | `lowrisc:prim:otp_pkg:0.1` | **DEPENDENCY_ONLY** | 0 | 0 | `/private/tmp/pi/census10/build/rtl/lowrisc_prim_otp_pkg_0.1/matrix-setup.log` |
| rtl | `lowrisc:prim:pad_attr:0` | **DEPENDENCY_ONLY** | 0 | 0 | `/private/tmp/pi/census10/build/rtl/lowrisc_prim_pad_attr_0/matrix-setup.log` |
| rtl | `lowrisc:prim:pad_wrapper:0` | **DEPENDENCY_ONLY** | 0 | 0 | `/private/tmp/pi/census10/build/rtl/lowrisc_prim_pad_wrapper_0/matrix-setup.log` |
| rtl | `lowrisc:prim:pad_wrapper_pkg:0` | **DEPENDENCY_ONLY** | 0 | 0 | `/private/tmp/pi/census10/build/rtl/lowrisc_prim_pad_wrapper_pkg_0/matrix-setup.log` |
| rtl | `lowrisc:prim:prim_dom_and_2share:0.1` | **UPSTREAM_INVALID** | 3 | 0 | `/private/tmp/pi/census10/build/rtl/lowrisc_prim_prim_dom_and_2share_0.1/matrix-compile.log` |
| rtl | `lowrisc:prim:prim_pkg:0.1` | **DEPENDENCY_ONLY** | 0 | 0 | `/private/tmp/pi/census10/build/rtl/lowrisc_prim_prim_pkg_0.1/matrix-setup.log` |
| rtl | `lowrisc:prim:primgen:0.1` | **SETUP_FAIL** | 0 | 0 | `/private/tmp/pi/census10/build/rtl/lowrisc_prim_primgen_0.1/matrix-setup.log` |
| rtl | `lowrisc:prim:ram_1p:0` | **DEPENDENCY_ONLY** | 0 | 0 | `/private/tmp/pi/census10/build/rtl/lowrisc_prim_ram_1p_0/matrix-setup.log` |
| rtl | `lowrisc:prim:ram_1p_adv:0.1` | **DEPENDENCY_ONLY** | 0 | 0 | `/private/tmp/pi/census10/build/rtl/lowrisc_prim_ram_1p_adv_0.1/matrix-setup.log` |
| rtl | `lowrisc:prim:ram_1p_pkg:0` | **DEPENDENCY_ONLY** | 0 | 0 | `/private/tmp/pi/census10/build/rtl/lowrisc_prim_ram_1p_pkg_0/matrix-setup.log` |
| rtl | `lowrisc:prim:ram_1p_scr:0.1` | **DEPENDENCY_ONLY** | 0 | 0 | `/private/tmp/pi/census10/build/rtl/lowrisc_prim_ram_1p_scr_0.1/matrix-setup.log` |
