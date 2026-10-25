package p; int c; endpackage
package q; int c; endpackage
module t; import p::*; import q::*; initial c = 1; endmodule
