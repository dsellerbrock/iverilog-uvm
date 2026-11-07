// NEG-DIAG: needs an assertion engine that cannot report a verdict per attempt
// NEG-DIAG-COUNT: 1
// IEEE 1800-2023 16.12.5 makes `P1 and P2' legal for any properties, but
// the per-attempt lowering of a property-level and/or can host only
// operands of the slot automaton. An operand that would need another
// engine (here the compact s_eventually liveness lowering) must be refused
// loudly; lowering it as a free-standing checker would report verdicts
// that are not combined with the other operand's attempt.
module sva_property_and_or_unhosted_operand;
  bit clk = 0, a, b, c, d;
  always #5 clk = ~clk;
  bad: assert property (@(posedge clk) (a |-> s_eventually b) and (c |-> d));
endmodule
