module sv_assert_first_match_cut_entry_multidepth_fail;
  bit clk, s4, x, y, z, a, b, c;
  int f4;
  assert property (@(posedge clk) s4 |->
    (x or (y ##1 z)) ##1 first_match(a ##[1:2] b) ##1 c) else f4++;
endmodule
