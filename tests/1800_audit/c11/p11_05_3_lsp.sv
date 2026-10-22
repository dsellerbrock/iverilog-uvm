module p11_05_3_lsp;
  localparam int p = 1;
  logic [7:0] m [0:1][0:1];
  logic [7:0] x = 8'h11, y = 8'h22;
  always_comb m[0][p] = x;
  always_comb m[1][0] = y;
  initial #1 $display("L1 %h %h", m[0][1], m[1][0]);
endmodule
