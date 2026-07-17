// M9D negative: a parameterized property that embeds its own clocking
// event is unsupported (would need per-instantiation event cloning);
// the clock must be supplied at the assertion. Loud sorry.
module top; logic clk=0,x,y;
  property pab(a,b); @(posedge clk) a |-> b; endproperty
  assert property (pab(x,y));
endmodule
