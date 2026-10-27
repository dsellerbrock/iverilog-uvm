checker issue945_check(logic s);
  bit a;
endchecker

module issue945_checker_hier_write;
  logic clk = 0;
  logic y = 0;
  issue945_check my_check(1'b0);
  always #1 clk = ~clk;
  always @(posedge clk) my_check.a = y;
endmodule
