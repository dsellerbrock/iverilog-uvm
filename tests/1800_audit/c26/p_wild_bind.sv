package p; int x; endpackage
module top;
  import p::*;
  if (1) begin : b
    initial x = 1;
    int x;
    initial x = 2;
  end
  initial #1 $display("P3 %0d %0d", p::x, b.x);
endmodule
