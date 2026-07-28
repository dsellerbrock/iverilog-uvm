// Unary temporal operators currently accept only a single-clock boolean
// operand. They must not consume only the suffix of a multiclocked operand
// and silently erase its clock-flow boundary.
module top;
  reg c1=0, c2=0, a=1, b=1;
  p: assert property (@(posedge c1)
       nexttime a ##0 @(posedge c2) b);
endmodule
