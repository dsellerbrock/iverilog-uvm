module sv_assert_first_match_tree_property_fail;
  bit clk, req, ack;
  assert property (@(posedge clk)
      first_match((req |-> ack) or (req ##1 ack)));
endmodule
