// IEEE 1800-2017 16.13.1 permits only ##0 (nearest at-or-after) and ##1
// (nearest strictly-after) at a clock-flow boundary. ##2 is illegal and
// must be rejected explicitly rather than treated as one of those forms.
module sva_multiclock_bad_boundary;
  reg c1=0, c2=1, a=0, b=0;
  always #5 c1=~c1; always #5 c2=~c2;
  p: assert property (@(posedge c1) a ##2 @(posedge c2) b);
  initial begin #50 $finish(0); end
endmodule
