// Count zero-time value changes on the lc_ctrl CSR/FSM feedback signals.
module loop_probe;
  timeunit 1ps; timeprecision 1ps;
  int n_idle, n_cmd, n_fsm_d, n_done, n_hw2reg, n_reg2hw, n_succ, n_tokreq, n_other;
  bit armed;
  initial begin #6606000; armed = 1; $display("ARMED t=%0t", $time); $fflush; end
  always @(tb.dut.lc_idle_d)          if (armed) n_idle++;
  always @(tb.dut.transition_cmd)     if (armed) n_cmd++;
  always @(tb.dut.u_lc_ctrl_fsm.fsm_state_d) if (armed) n_fsm_d++;
  always @(tb.dut.lc_done_d)          if (armed) n_done++;
  always @(tb.dut.hw2reg)             if (armed) n_hw2reg++;
  always @(tb.dut.reg2hw)             if (armed) n_reg2hw++;
  always @(tb.dut.u_lc_ctrl_fsm.trans_success_o) if (armed) n_succ++;
  always @(tb.dut.u_lc_ctrl_fsm.token_hash_req_o) if (armed) n_tokreq++;
  always @(tb.dut.u_lc_ctrl_fsm.lc_state_d or tb.dut.u_lc_ctrl_fsm.lc_cnt_d) if (armed) n_other++;
  int n_swc, n_tapc, n_tok, n_tgt, n_vend, n_ext, n_vol;
  always @(tb.dut.sw_claim_transition_if_d) if (armed) n_swc++;
  always @(tb.dut.tap_claim_transition_if_d) if (armed) n_tapc++;
  always @(tb.dut.transition_token_d) if (armed) n_tok++;
  always @(tb.dut.transition_target_d) if (armed) n_tgt++;
  always @(tb.dut.otp_vendor_test_ctrl_d) if (armed) n_vend++;
  always @(tb.dut.use_ext_clock_d) if (armed) n_ext++;
  always @(tb.dut.volatile_raw_unlock_d) if (armed) n_vol++;
  int next_report = 20;
  always @(n_idle or n_cmd or n_fsm_d or n_hw2reg or n_reg2hw or n_done or n_succ or n_tokreq or n_other or n_swc or n_tapc or n_tok or n_tgt or n_vend or n_ext or n_vol)
    if (n_idle + n_cmd + n_fsm_d + n_done + n_hw2reg + n_reg2hw + n_succ + n_tokreq + n_other + n_swc + n_tapc + n_tok + n_tgt + n_vend + n_ext + n_vol >= next_report) begin
      next_report = next_report * 4; $fflush;
      $display("LOOP t=%0t idle=%0d cmd=%0d fsm_d=%0d done=%0d hw2reg=%0d reg2hw=%0d succ=%0d tokreq=%0d st/cnt=%0d swc=%0d tapc=%0d tok=%0d tgt=%0d vend=%0d ext=%0d vol=%0d fsm_state_d=%0d fsm_q=%0d",
        $time, n_idle, n_cmd, n_fsm_d, n_done, n_hw2reg, n_reg2hw, n_succ, n_tokreq, n_other, n_swc, n_tapc, n_tok, n_tgt, n_vend, n_ext, n_vol,
        tb.dut.u_lc_ctrl_fsm.fsm_state_d, tb.dut.u_lc_ctrl_fsm.fsm_state_q);
      $fflush;
      if (next_report > 400000) $finish;
    end
endmodule
