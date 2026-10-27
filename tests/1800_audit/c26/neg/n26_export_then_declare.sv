package p1; int x; endpackage
package p6; import p1::*; export p1::x; int x; endpackage
module t; endmodule
