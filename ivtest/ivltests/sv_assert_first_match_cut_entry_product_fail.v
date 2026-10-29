module sv_assert_first_match_cut_entry_product_fail;
  bit clk, sp, a, b, c, d, e;
  int fp;
  assert property (@(posedge clk) sp |->
    (first_match(a ##[1:2] b) and (c ##1 d)) ##1 e) else fp++;
endmodule
