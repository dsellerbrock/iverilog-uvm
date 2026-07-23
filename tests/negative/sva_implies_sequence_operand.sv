// The property combinators (implies/iff/if/case, IEEE 1800-2017 16.12.8) are
// supported in this engine only over BOOLEAN operands, where each collapses
// to a single boolean property. A multi-cycle SEQUENCE operand cannot be
// collapsed that way, so it must be rejected with a loud diagnostic rather
// than silently miscompiled.
module sva_implies_sequence_operand;
  logic clk = 0, a = 0, b = 0, c = 0;
  always #5 clk = ~clk;
  // `b ##1 c' is a two-cycle sequence -> not a boolean operand.
  bad: assert property (@(posedge clk) a implies (b ##1 c));
endmodule
