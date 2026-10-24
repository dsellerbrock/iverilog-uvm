package p1; int x = 5, y = 6; endpackage
package p2; import p1::x; export p1::*; endpackage
package p4; import p1::*; export p1::*; int yy = x; endpackage
module top;
  import p2::*;
  import p4::*;
  int y2 = x;
  initial #1 $display("P7 %0d %0d", y2, yy);
endmodule
