`default_nettype uwire
module issue3396_default_uwire_fail;
  assign w = 1'b0;
  assign w = 1'b1;
endmodule
`default_nettype wire
