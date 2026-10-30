nettype logic bit_t;

module issue1513_nettype_multiple_delay;
  logic src;
  bit_t dst;

  assign #(2, 3, 4) dst = src;
endmodule
