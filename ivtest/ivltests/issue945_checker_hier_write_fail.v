checker issue945_check(input logic s);
  bit a;
endchecker

module issue945_checker_hier_write_fail;
  logic clk = 0;
  logic y = 1;
  issue945_check my_check(1'b0);
  always #1 clk = ~clk;
  always @(posedge clk) my_check.a = y;
endmodule
