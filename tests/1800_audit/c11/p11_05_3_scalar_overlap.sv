module p11_05_3_scalar_overlap;
  logic z;
  logic x = 1, y = 0;
  always_comb z = x;
  always_comb z = y;
endmodule
