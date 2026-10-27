package p;
  int x;
endpackage
module m;
  import p::*;
  if (1) begin : b
    initial x = 1;
    int x;
    initial x = 1;
  end
  int x;
endmodule
