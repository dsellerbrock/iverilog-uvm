// The current property-combinator lowering handles only single-cycle boolean
// branches. A multiclocked branch must be rejected loudly; treating its
// second-clock suffix as that boolean would silently discard the prefix and
// clock-flow boundary.
module top;
  reg c1=0, c2=0, sel=1, a=1, b=1;
  p: assert property (@(posedge c1)
       if (sel) a ##0 @(posedge c2) b else 1'b1);
endmodule
