// M9B negative: `intersect` requires equal-length operands. A shorter
// operand can never match over the same interval; must be rejected.
module top; logic clk=0,a,b,c;
  assert property (@(posedge clk) (a ##1 b) intersect (c));
endmodule
