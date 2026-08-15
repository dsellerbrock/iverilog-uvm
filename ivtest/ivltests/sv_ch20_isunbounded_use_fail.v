// IEEE 1800-2017 6.20.2.1: an unbounded parameter is not an unknown or
// arbitrarily large integer and cannot participate in arithmetic.
module test;
  parameter int U = $;
  localparam int BAD = U + 1;
endmodule
