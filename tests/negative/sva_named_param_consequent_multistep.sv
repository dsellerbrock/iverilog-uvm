// NEG-DIAG: this parameter-valued consecutive repetition composition is not supported
// A legal multi-step sequence cannot be collapsed into a Boolean antecedent.
module sva_named_param_consequent_multistep;
  parameter integer W = 2;
  logic clk, start, ready;
  sequence pair(s, r);
    s ##1 r;
  endsequence
  assert property (@(posedge clk)
    pair(start, ready) |=> !ready[*W] ##1 ready);
endmodule
