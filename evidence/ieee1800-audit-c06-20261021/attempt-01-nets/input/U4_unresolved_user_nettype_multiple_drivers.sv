package P;
  typedef struct { real field1; bit field2; } T;
  nettype T wT;
endpackage
module top;
  import P::*;
  wT n;
  assign n = '{1.5, 1'b1};
  assign n = '{2.0, 1'b0};
  initial $display("%0.1f", n.field1);
endmodule
