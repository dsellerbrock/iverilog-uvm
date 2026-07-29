// M9-7 residual: IEEE 1800-2017 16.13.1 permits only ##0 or ##1 at EVERY
// clock-flow boundary in a chain, not just the first one. The SECOND
// boundary here is ##2, which must be rejected explicitly rather than
// silently accepted as one of the two legal forms.
module top;
  reg c1=0, c2=0, c3=0, req=0, b=0, c=0;
  always #5 c1=~c1; always #7 c2=~c2; always #11 c3=~c3;
  p: assert property (@(posedge c1) req |=> @(posedge c2) b ##2 @(posedge c3) c);
  initial begin #50 $finish(0); end
endmodule
