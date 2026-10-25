checker check(logic s);
  bit a;
endchecker

module sv_checker_hier_var_fail_2017;
  logic clk, y;
  check my_check(1'b0);
  wire x = my_check.a;
  always @(posedge clk) my_check.a = y;
endmodule
