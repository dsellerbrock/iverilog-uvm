package P;
  typedef struct { real field1; bit field2; } T;
  nettype T wT;
endpackage
module top;
  import P::*;
  T d1 = '{1.5, 1'b1};
  T d2 = '{2.0, 1'b0};
  wT n;
  assign n = d1;
  assign n = d2;
  initial $display("%0.1f", n.field1);
endmodule
