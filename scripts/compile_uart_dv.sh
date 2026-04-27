#!/usr/bin/env bash
# Compile the OpenTitan UART DV testbench to /tmp/uart_dv.vvp using the
# locally built iverilog. Source list reconstructed from /tmp/uart_dv.vvp's
# embedded file references (extracted from the previous successful build).

set -u
cd "$(dirname "$0")/.."

IVERILOG=iverilog/install/bin/iverilog
UVM=accellera-official.uvm-core/src
OUT=/tmp/uart_dv.vvp

INC_DIRS=(
  -I "$UVM"
  -I opentitan/hw/dv/sv/dv_utils
  -I opentitan/hw/dv/sv/cip_lib
  -I opentitan/hw/ip/prim/rtl
  -I opentitan/hw/ip/prim_generic/rtl
  -I opentitan/hw/ip/tlul/rtl
  -I opentitan/hw/ip/uart/dv/env
  -I opentitan/hw/ip/uart/dv/env/seq_lib
  -I opentitan/hw/ip/uart/dv/tests
  -I opentitan/hw/ip/uart/rtl
  -I opentitan/hw/dv/sv/alert_esc_agent
  -I opentitan/hw/dv/sv/alert_esc_agent/seq_lib
  -I opentitan/hw/dv/sv/cip_lib/seq_lib
  -I opentitan/hw/dv/sv/common_ifs
  -I opentitan/hw/dv/sv/csr_utils
  -I opentitan/hw/dv/sv/dv_base_reg
  -I opentitan/hw/dv/sv/dv_lib
  -I opentitan/hw/dv/sv/dv_lib/seq_lib
  -I opentitan/hw/dv/sv/mem_model
  -I opentitan/hw/dv/sv/push_pull_agent
  -I opentitan/hw/dv/sv/push_pull_agent/seq_lib
  -I opentitan/hw/dv/sv/sec_cm
  -I opentitan/hw/dv/sv/str_utils
  -I opentitan/hw/dv/sv/tl_agent
  -I opentitan/hw/dv/sv/tl_agent/seq_lib
  -I opentitan/hw/dv/sv/uart_agent
  -I opentitan/hw/dv/sv/uart_agent/seq_lib
  -I opentitan/hw/top_earlgrey/rtl
)

# Files in dependency order: RTL pkgs first, then DV pkgs, then interfaces,
# then RTL modules, then test pkg, then top tb.
# (Interfaces must precede modules that import them; pkgs must precede
# anything that imports them.)
SRC=(
  # RTL packages (bottom-up)
  opentitan/hw/ip/prim/rtl/prim_util_pkg.sv
  opentitan/hw/ip/prim/rtl/prim_mubi_pkg.sv
  opentitan/hw/ip/prim/rtl/prim_subreg_pkg.sv
  opentitan/hw/top_earlgrey/rtl/top_pkg.sv
  opentitan/hw/top_earlgrey/rtl/autogen/top_racl_pkg.sv
  opentitan/hw/ip/prim/rtl/prim_secded_pkg.sv
  opentitan/hw/ip/prim_generic/rtl/prim_pkg.sv
  opentitan/hw/ip/prim/rtl/prim_alert_pkg.sv
  opentitan/hw/ip/prim/rtl/prim_esc_pkg.sv
  opentitan/hw/ip/lc_ctrl/rtl/lc_ctrl_state_pkg.sv
  opentitan/hw/ip/lc_ctrl/rtl/lc_ctrl_pkg.sv
  opentitan/hw/ip/tlul/rtl/tlul_pkg.sv
  opentitan/hw/ip/uart/rtl/uart_reg_pkg.sv

  # UVM
  "$UVM/uvm_pkg.sv"

  # common_ifs_pkg must precede the interfaces that import it
  opentitan/hw/dv/sv/common_ifs/common_ifs_pkg.sv
  opentitan/hw/dv/sv/common_ifs/clk_rst_if.sv
  opentitan/hw/dv/sv/common_ifs/pins_if.sv
  opentitan/hw/dv/sv/common_ifs/rst_shadowed_if.sv

  # DV packages (strict dep order)
  opentitan/hw/dv/sv/bus_params_pkg/bus_params_pkg.sv
  opentitan/hw/dv/sv/dv_utils/dv_utils_pkg.sv
  opentitan/hw/dv/sv/str_utils/str_utils_pkg.sv
  opentitan/hw/dv/sv/sec_cm/sec_cm_pkg.sv
  opentitan/hw/dv/sv/mem_model/mem_model_pkg.sv
  opentitan/hw/dv/sv/dv_base_reg/dv_base_reg_pkg.sv
  opentitan/hw/dv/sv/csr_utils/csr_utils_pkg.sv
  opentitan/hw/dv/sv/dv_lib/dv_lib_pkg.sv
  opentitan/hw/dv/sv/push_pull_agent/push_pull_agent_pkg.sv
  opentitan/hw/dv/sv/tl_agent/tl_agent_pkg.sv
  opentitan/hw/dv/sv/alert_esc_agent/alert_esc_agent_pkg.sv
  opentitan/hw/dv/sv/uart_agent/uart_agent_pkg.sv
  opentitan/hw/dv/sv/cip_lib/cip_base_pkg.sv

  # UART RAL
  opentitan/hw/ip/uart/dv/env/uart_ral_pkg.sv
  opentitan/hw/ip/uart/dv/env/uart_env_pkg.sv
  opentitan/hw/ip/uart/dv/tests/uart_test_pkg.sv

  # Interfaces (referenced by tb.sv) — common_ifs already added above
  opentitan/hw/dv/sv/alert_esc_agent/alert_esc_if.sv
  opentitan/hw/dv/sv/alert_esc_agent/alert_esc_probe_if.sv
  opentitan/hw/dv/sv/push_pull_agent/push_pull_if.sv
  opentitan/hw/dv/sv/tl_agent/tl_if.sv
  opentitan/hw/dv/sv/uart_agent/uart_if.sv
  opentitan/hw/ip/uart/dv/env/uart_nf_if.sv

  # RTL primitives & TLUL
  opentitan/hw/ip/prim/rtl/prim_assert.sv
  opentitan/hw/ip/prim_generic/rtl/prim_buf.sv
  opentitan/hw/ip/prim_generic/rtl/prim_flop.sv
  opentitan/hw/ip/prim_generic/rtl/prim_flop_2sync.sv
  opentitan/hw/ip/prim_generic/rtl/prim_flop_en.sv
  opentitan/hw/ip/prim/rtl/prim_sec_anchor_buf.sv
  opentitan/hw/ip/prim/rtl/prim_sec_anchor_flop.sv
  opentitan/hw/ip/prim/rtl/prim_diff_decode.sv
  opentitan/hw/ip/prim/rtl/prim_fifo_sync_cnt.sv
  opentitan/hw/ip/prim/rtl/prim_fifo_sync.sv
  opentitan/hw/ip/prim/rtl/prim_intr_hw.sv
  opentitan/hw/ip/prim/rtl/prim_alert_sender.sv
  opentitan/hw/ip/prim/rtl/prim_arbiter_tree.sv
  opentitan/hw/ip/prim/rtl/prim_arbiter_tree_dup.sv
  opentitan/hw/ip/prim/rtl/prim_subreg.sv
  opentitan/hw/ip/prim/rtl/prim_subreg_ext.sv
  opentitan/hw/ip/prim/rtl/prim_subreg_arb.sv
  opentitan/hw/ip/prim/rtl/prim_reg_we_check.sv
  opentitan/hw/ip/prim/rtl/prim_onehot_check.sv
  opentitan/hw/ip/prim/rtl/prim_secded_inv_64_57_dec.sv
  opentitan/hw/ip/prim/rtl/prim_secded_inv_64_57_enc.sv
  opentitan/hw/ip/prim/rtl/prim_secded_inv_39_32_dec.sv
  opentitan/hw/ip/prim/rtl/prim_secded_inv_39_32_enc.sv
  opentitan/hw/ip/tlul/rtl/tlul_cmd_intg_chk.sv
  opentitan/hw/ip/tlul/rtl/tlul_rsp_intg_gen.sv
  opentitan/hw/ip/tlul/rtl/tlul_adapter_reg.sv
  opentitan/hw/ip/tlul/rtl/tlul_data_integ_dec.sv
  opentitan/hw/ip/tlul/rtl/tlul_data_integ_enc.sv
  opentitan/hw/ip/tlul/rtl/tlul_err.sv

  # UART RTL modules
  opentitan/hw/ip/uart/rtl/uart_reg_top.sv
  opentitan/hw/ip/uart/rtl/uart_rx.sv
  opentitan/hw/ip/uart/rtl/uart_tx.sv
  opentitan/hw/ip/uart/rtl/uart_core.sv
  opentitan/hw/ip/uart/rtl/uart.sv

  # Top testbench (last)
  opentitan/hw/ip/uart/dv/tb/tb.sv
)

ulimit -v 3000000
exec "$IVERILOG" -g2012 -DUVM_NO_DPI -DUVM -DICARUS \
  "${INC_DIRS[@]}" -o "$OUT" "${SRC[@]}"
