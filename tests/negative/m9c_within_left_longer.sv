// M9C negative: `within` requires the left operand to be no longer than
// the right (it must fit inside). A longer left operand is rejected.
module top; logic clk=0,a,b,c,d;
  assert property (@(posedge clk) (a ##2 b) within (c ##1 d));
endmodule
