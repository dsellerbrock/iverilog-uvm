module sv_assert_increment_side_effect_2017;
  bit clk = 0;
  int cnt = 0;

  always #5 clk = ~clk;

  assert property (@(posedge clk) (cnt++ > 0));
endmodule
