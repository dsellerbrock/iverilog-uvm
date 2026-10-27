module test;
  bit clk = 0, a = 0;
  always #5 clk = ~clk;
  assert property (@(posedge clk) eventually a);
endmodule
