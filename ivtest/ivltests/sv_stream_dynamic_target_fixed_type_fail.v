// A fixed real member remains illegal even when another target member is
// dynamically sized. Diagnose the source construct before target lowering.
module test;
  real fixed_real;
  byte data[];
  initial {>>{fixed_real, data}} = 64'h0;
endmodule
