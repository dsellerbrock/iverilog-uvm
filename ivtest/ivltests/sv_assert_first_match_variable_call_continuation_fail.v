// A variable-length first_match call before an outer continuation remains unsupported.
module sv_assert_first_match_variable_call_continuation_fail;
  logic clk = 0, a = 0, b = 0, c = 0;
  always #5 clk = ~clk;

  cover property (@(posedge clk)
                  first_match(a ##[1:3] b, $display("x")) ##1 c);
endmodule
