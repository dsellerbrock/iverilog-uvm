// NEG-DIAG: a property is used where this operator requires a sequence operand
// IEEE 1800-2023 16.12.4/16.12.5: `and'/`or' accept full properties only as
// property operators. A property-level conjunction is not a sequence, so
// it cannot be an implication antecedent (16.12.7: the antecedent is a
// sequence_expr) and must be rejected rather than read as sequence `and'.
module sva_property_and_or_sequence_context;
  bit clk = 0, a, b, c, d;
  always #5 clk = ~clk;
  bad: assert property (@(posedge clk) ((a |-> b) and c) |-> d);
endmodule
