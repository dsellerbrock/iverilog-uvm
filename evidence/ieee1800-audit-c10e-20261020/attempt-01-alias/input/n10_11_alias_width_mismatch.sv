module n10_11_alias_width_mismatch;
  wire [3:0] x;
  wire [7:0] y;
  alias x = y;
endmodule
