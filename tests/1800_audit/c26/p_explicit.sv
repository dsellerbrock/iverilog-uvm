package p; typedef enum {FALSE, TRUE} bool_t; endpackage
package q; typedef enum {ORIGINAL, FALSE} teeth_t; endpackage
module top;
  import p::*;
  import q::teeth_t, q::ORIGINAL, q::FALSE;
  teeth_t t;
  initial begin t = FALSE; $display("P1 %0d", t); end
endmodule
