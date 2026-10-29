module sv_assert_first_match_nonlocal_assignment_fail;
  logic clk = 0, a = 0;
  int written = 0;
  always #5 clk = ~clk;

  cover property (@(posedge clk) first_match(a, written = 1));
endmodule
