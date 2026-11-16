// IEEE 1800 22.8: `default_nettype uwire; an implicit net is a uwire.
`default_nettype uwire
module top;
  assign w = 1'b1;
  initial #1 $display("w=%b", w);
endmodule
`default_nettype wire
