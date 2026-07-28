// A variable-length multiclock antecedent can produce more than one match,
// hence more than one obligation, from a single starting attempt. The
// fixed-chain request-counter lowering does not yet retain that branch
// identity, so this legal residual must remain a loud diagnostic rather
// than silently collapsing the matches.
module top;
  reg c1=0, c2=0, a=0, b=0;
  p: assert property (@(posedge c1) a[*1:2] |=> @(posedge c2) b);
endmodule
