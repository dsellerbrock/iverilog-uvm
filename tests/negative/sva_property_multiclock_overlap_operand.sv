// NEG-DIAG: this multiclocked operand of a property operator is not supported yet
// NEG-DIAG-COUNT: 1
// IEEE 1800-2023 16.13.2: `s |-> @(c) t' waits for the nearest, possibly
// overlapping tick of c. The per-attempt clock switch of a property
// operator implements only the strictly-subsequent boundaries (`|=> @(c)',
// `##1 @(c)'), so an overlapping one must be refused loudly.
module sva_property_multiclock_overlap_operand;
  bit clk = 0, clk1 = 0, a, b, c, d;
  always #5 clk = ~clk;
  always #7 clk1 = ~clk1;
  bad: assert property (@(posedge clk) if (c) (a |-> @(posedge clk1) d) else b);
endmodule
