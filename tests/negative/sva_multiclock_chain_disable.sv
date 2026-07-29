// M9-7 residual: `disable iff' composed with more than one clock-flow
// change in the same sequence is not lowered -- the 2-domain handoff's
// disable_iff support (clearing both domains' pipeline state without
// bumping req, swallowing an outstanding obligation) does not yet
// generalize past a single boundary, so this stays a loud diagnostic
// rather than silently ignoring `disable iff' or silently narrowing to
// two domains. The single clock-flow-boundary form (`@(c1) a |=>
// @(c2) b') keeps supporting `disable iff' -- see
// tests/sva_nfa/disable_sampled.sv.
module top;
  reg c1=0, c2=0, c3=0, req=0, b=0, c=0, rst=0;
  always #5 c1=~c1; always #7 c2=~c2; always #11 c3=~c3;
  p: assert property (@(posedge c1) disable iff (rst)
                       req |=> @(posedge c2) b ##1 @(posedge c3) c);
  initial begin #50 $finish(0); end
endmodule
