module child;
endmodule

module test;
  child dut();
  initial dut.missing();
endmodule
