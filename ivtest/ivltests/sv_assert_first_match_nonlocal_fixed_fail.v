module sv_assert_first_match_nonlocal_fixed_fail;
  bit clk=0, a=0, b=0, c=0;
  int x=0, d=0;
  always #5 clk=~clk;
  cover property (@(posedge clk) first_match(a ##[1:2] (b, x=d) ##1 c));
endmodule
