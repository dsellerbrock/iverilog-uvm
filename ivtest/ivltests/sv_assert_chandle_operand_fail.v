module sv_assert_chandle_operand_fail;
  logic clk = 0;
  chandle handle_value;

  always #5 clk = ~clk;
  assert property (@(posedge clk) handle_value == null);

  initial #12 $finish;
endmodule
