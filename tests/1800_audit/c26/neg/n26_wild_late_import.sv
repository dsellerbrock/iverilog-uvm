package q; int c = 0; endpackage
package p; const int c = 1; endpackage
module m;
  import q::*;
  wire a = c;
  import p::c;
endmodule
