module m(input logic clk,a,b,c,d);
  ap: assert property (@(posedge clk) (a ##1 b) or (c ##1 d) |-> c);
endmodule
