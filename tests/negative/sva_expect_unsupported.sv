// M9-11: `expect' now lowers fixed chains procedurally and every other
// plain-sequence shape (windows, repetition, goto, unbounded waits,
// or/and/intersect trees) through the automaton engine as an inline
// single attempt. PROPERTY operators remain outside the sequence
// automaton: an implication (|->/|=>), strong/weak, negation, or
// multiclock expect must stay a loud sorry, never a silent drop.
module sva_expect_unsupported;
  logic clk=0, a=0, b=0;
  always #5 clk=~clk;
  initial expect (@(posedge clk) a |-> b) $display("P"); else $display("Q");
endmodule
