// A statically known source that is shorter than the fixed portion of a
// dynamic streaming target is rejected during elaboration.
module test;
  logic [15:0] fixed;
  byte data[];
  initial {>>{fixed, data}} = 8'hA5;
endmodule
