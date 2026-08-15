// IEEE 1800-2017 6.20.2.1 limits `$' to parameters of integer types.
module test;
  parameter real BAD = $;
endmodule
