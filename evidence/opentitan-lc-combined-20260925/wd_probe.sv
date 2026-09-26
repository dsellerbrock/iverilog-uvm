module wd_probe;
  timeunit 1ps; timeprecision 1ps;
  always @(tb.dut.u_reg.reg_wdata or tb.dut.u_reg.reg_we or tb.dut.u_reg.tl_i or tb.dut.u_reg.transition_token_0_wd or tb.dut.reg2hw.transition_token[0])
    if ($time > 6100000 && $time < 6150000) begin
      $display("DPROBE t=%0t a_valid=%b a_opcode=%0d a_data=%h | reg_we=%b reg_wdata=%h tok0_wd=%h | r2h.tok0=%h",
        $time, tb.dut.u_reg.tl_i.a_valid, tb.dut.u_reg.tl_i.a_opcode, tb.dut.u_reg.tl_i.a_data,
        tb.dut.u_reg.reg_we, tb.dut.u_reg.reg_wdata, tb.dut.u_reg.transition_token_0_wd,
        tb.dut.reg2hw.transition_token[0]);
      $fflush;
    end
  initial begin #6150000; $finish; end
endmodule
