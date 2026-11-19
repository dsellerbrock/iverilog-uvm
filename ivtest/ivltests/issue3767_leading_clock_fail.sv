module issue3767_leading_clock_fail;
  bit clk1;
  wire clk2 = clk1;
  bit a, b;

  assert property ((@(posedge clk1) a) and (@(posedge clk2) b));
endmodule
