// M9C negative: the `until' family supports boolean operands only; a
// sequence operand must be rejected rather than silently mishandled.
module top; logic clk=0,a,b,q;
  assert property (@(posedge clk) (a ##1 b) until q);
endmodule
