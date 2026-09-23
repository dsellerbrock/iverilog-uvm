module sv_assert_named_param_consequent_multistep_negative;
  parameter integer W = 2;
  reg clk = 0, start = 0, ready = 0;
  sequence Pair(s, r);
    s ##1 r;
  endsequence
  // The focused one-step checker cannot collapse this two-edge antecedent.
  assert property (@(posedge clk)
    Pair(start, ready) |=> !ready[*W] ##1 ready);
endmodule
