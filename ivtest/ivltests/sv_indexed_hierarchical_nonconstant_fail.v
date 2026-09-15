module child;
  task bump; endtask
endmodule

module test;
  child dut[1:0]();
  int index = 1;
  initial begin
    dut[index].bump();
    dut[1'bx].bump();
  end
endmodule
