module sv_assert_first_match_cut_entry_rep_goto_fail;
  bit clk, s, a, b, c;
  int fail_count;
  assert property (@(posedge clk) s |->
    first_match(a ##1 b[->1:2]) ##1 c) else fail_count++;
endmodule
