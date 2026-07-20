// M9-NFA stage D.1: a multiclocked OVERLAPPING implication
// `@(c1) a |-> @(c2) b' has at-or-after cross-clock consequent timing
// that the request/ack handoff (strictly-after) does not model, so it
// must be a loud sorry rather than silently lowered as non-overlapping.
module sva_multiclock_ov;
  reg c1=0, c2=1, a=0, b=0;
  always #5 c1=~c1; always #5 c2=~c2;
  p: assert property (@(posedge c1) a |-> @(posedge c2) b);
  initial begin #50 $finish(0); end
endmodule
