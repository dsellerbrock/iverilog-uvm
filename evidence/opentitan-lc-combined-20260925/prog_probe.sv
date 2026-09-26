// Trace the lc_ctrl FSM and its OTP/KMAC handshakes around the first transition.
module prog_probe;
  timeunit 1ps; timeprecision 1ps;
  bit armed;
  initial begin #6600000; armed = 1; #3000000; $display("PROBE END t=%0t state=%0d", $time, tb.dut.u_lc_ctrl_fsm.fsm_state_q); $fflush; $finish; end
  always @(tb.dut.u_lc_ctrl_fsm.fsm_state_q)
    if (armed) begin $display("PROBE t=%0t fsm_state_q=%0d", $time, tb.dut.u_lc_ctrl_fsm.fsm_state_q); $fflush; end
  always @(tb.dut.u_lc_ctrl_fsm.otp_prog_req_o or tb.dut.u_lc_ctrl_fsm.otp_prog_ack_i or tb.dut.u_lc_ctrl_fsm.otp_prog_err_i)
    if (armed) begin $display("PROBE t=%0t otp req=%b ack=%b err=%b", $time, tb.dut.u_lc_ctrl_fsm.otp_prog_req_o, tb.dut.u_lc_ctrl_fsm.otp_prog_ack_i, tb.dut.u_lc_ctrl_fsm.otp_prog_err_i); $fflush; end
  always @(tb.dut.lc_otp_program_o or tb.dut.lc_otp_program_i)
    if (armed) begin $display("PROBE t=%0t lc_otp_program_o=%h lc_otp_program_i=%h", $time, tb.dut.lc_otp_program_o, tb.dut.lc_otp_program_i); $fflush; end
endmodule
