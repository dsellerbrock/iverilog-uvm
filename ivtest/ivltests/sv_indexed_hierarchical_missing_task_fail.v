module child;
endmodule

module test;
  child dut[1:0]();
  initial dut[1].missing();
endmodule
