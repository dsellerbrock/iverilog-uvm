module child;
  task bump; endtask
endmodule

module test;
  child dut[1:0]();
  initial dut[128'h1_0000_0000_0000_0001].bump();
endmodule
