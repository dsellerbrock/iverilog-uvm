// Issue #885 (IEEE 1800 Annex K): the VPI module checks every Annex K name
// in vpi_user.h when it compiles; $probe reports that it loaded.
module top;
  initial $probe;
endmodule
