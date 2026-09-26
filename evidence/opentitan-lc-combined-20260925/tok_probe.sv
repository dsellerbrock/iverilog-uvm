module tok_probe;
  timeunit 1ps; timeprecision 1ps;
  always @(tb.dut.transition_token_q or tb.dut.transition_token_d or tb.dut.reg2hw.transition_token)
    if ($time > 6100000 && $time < 6700000) begin
      $display("TPROBE t=%0t reg2hw.tok=%h tok_d=%h tok_q=%h swclaim_q=%h", $time,
        tb.dut.reg2hw.transition_token, tb.dut.transition_token_d, tb.dut.transition_token_q,
        tb.dut.sw_claim_transition_if_q);
      $fflush;
    end
  initial begin #6700000; $display("TPROBE end tok_q=%h", tb.dut.transition_token_q); $fflush; $finish; end
endmodule
