// NEG-DIAG: No function named `MissingSequence'
// An undeclared antecedent must not be dropped as a sequence.
module sva_named_param_consequent_unknown;
  parameter integer W = 2;
  logic clk, start, ready;
  assert property (@(posedge clk)
    MissingSequence(start) |=> !ready[*W] ##1 ready);
endmodule
