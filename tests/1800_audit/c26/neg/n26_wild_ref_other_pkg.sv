package p; typedef enum {FALSE, TRUE} bool_t; endpackage
package q; typedef enum {ORIGINAL, FALSE} teeth_t; endpackage
module top;
  import p::*;
  import q::teeth_t;
  teeth_t t;
  initial t = FALSE;
endmodule
