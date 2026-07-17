// M9D negative: a parameterized sequence instantiated with the wrong
// number of arguments must be rejected (not silently mis-instantiated).
module top; logic clk=0,x;
  sequence sab(a,b); a ##1 b; endsequence
  assert property (@(posedge clk) sab(x));
endmodule
