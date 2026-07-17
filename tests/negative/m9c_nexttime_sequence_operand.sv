// M9C-live negative: `nexttime' takes a boolean operand; a sequence
// operand is unsupported and must be a loud sorry.
module top; logic clk=0,a,b;
  assert property (@(posedge clk) nexttime (a ##1 b));
endmodule
