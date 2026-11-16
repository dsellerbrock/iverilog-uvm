// A uwire net allows one driver (6.6.1): two continuous assigns to an
// implicit uwire net are an error.
`default_nettype uwire
module top;
  assign w = 1'b1;
  assign w = 1'b0;
endmodule
`default_nettype wire
