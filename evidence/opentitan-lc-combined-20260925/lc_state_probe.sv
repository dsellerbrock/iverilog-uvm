// Passive observer (diagnostic only): LC FSM error inputs over time.
module lc_state_probe;
  `define F tb.dut.u_lc_ctrl_fsm
  always @(`F.state_invalid_error or `F.fsm_state_q or `F.token_if_fsm_err_i
           or `F.lc_state_valid_q or `F.lc_cnt_q or `F.secrets_valid_i
           or `F.esc_scrap_state0_i or `F.esc_scrap_state1_i)
    if ($time > 0)
      $display("PROBE t=%0t fsm=%h sie=%b tokerr=%b valid=%b cnt=%h secrets=%h esc=%b%b lc_state=%h",
               $time, `F.fsm_state_q, `F.state_invalid_error, `F.token_if_fsm_err_i,
               `F.lc_state_valid_q, `F.lc_cnt_q, `F.secrets_valid_i,
               `F.esc_scrap_state0_i, `F.esc_scrap_state1_i, `F.lc_state_q);
endmodule
