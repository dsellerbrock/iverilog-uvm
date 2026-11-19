// IEEE 1800-2017/2023 16.10, 16.11
module sv_assert_first_match_tree_items_fail;
  bit clk, a, b;
  int outside;
  cover sequence (@(posedge clk) first_match(a or b, outside = 1));
  cover sequence (@(posedge clk) first_match(a[*0:1] or b, $display("empty")));
endmodule
