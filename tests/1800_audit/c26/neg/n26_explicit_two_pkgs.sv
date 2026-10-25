package p; int c; endpackage
package q; int c; endpackage
module t; import p::c; import q::c; endmodule
