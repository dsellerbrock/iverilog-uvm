// Variable-length first_match calls remain unsupported until NFA cuts gate actions.
module sv_assert_first_match_variable_call_fail;
  logic clk = 0, a = 0, b = 0;
  always #5 clk = ~clk;

  assert property (@(posedge clk)
                   first_match(a ##[1:3] b, $display("x")));
endmodule
