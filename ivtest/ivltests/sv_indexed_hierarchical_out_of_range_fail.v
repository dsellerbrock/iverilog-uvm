module child;
  task bump; endtask
endmodule

module test;
  child dut[1:0]();
  initial dut[2].bump();
endmodule
