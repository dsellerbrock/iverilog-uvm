// IEEE 1800-2023 16.8.1 also covers a property's sequence-typed formal.
module issue2990_prop_formal_goto_ce;
  bit clk, a, b;
  property p(sequence q); @(posedge clk) q[->1] |-> b; endproperty
  assert property (p(a));
endmodule
