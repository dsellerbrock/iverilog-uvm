package p;
  int x = 99;
endpackage
module m;
  import p::*;
  int x = 2;
  initial $display("%0d", x);
endmodule
