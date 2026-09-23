module sv_assert_named_param_consequent_unknown_negative;
  parameter integer W = 2;
  reg clk = 0, start = 0, ready = 0;
  // Unknown names are not treated as Boolean functions or silently dropped.
  assert property (@(posedge clk)
    MissingSequence(start) |=> !ready[*W] ##1 ready);
endmodule
