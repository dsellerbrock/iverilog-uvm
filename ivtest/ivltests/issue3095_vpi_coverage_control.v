module dut;
  wire signal = 1'b0;
endmodule

module top;
  dut u();
  initial $probe_coverage_control;
endmodule
