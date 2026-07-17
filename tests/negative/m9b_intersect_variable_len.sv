// M9B negative: `intersect` over a variable-length (##[m:n]) operand is
// not supported by the fixed-length lowering; must be a loud sorry.
module top; logic clk=0,a,b,c,d;
  assert property (@(posedge clk) (a ##[1:2] b) intersect (c ##1 d));
endmodule
