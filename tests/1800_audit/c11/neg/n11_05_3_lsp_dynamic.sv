module n11_05_3_lsp_dynamic;
  logic [7:0] m [0:1][0:1];
  logic [7:0] x = 8'h11, y = 8'h22;
  integer i = 0;
  always_comb m[i][0] = x;
  always_comb m[1][0] = y;
endmodule
