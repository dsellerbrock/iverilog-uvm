module sv_always_comb_longest_static_prefix_overlap;
  logic [7:0] m [0:1][0:1];
  logic [7:0] x, y;
  integer i = 0;
  localparam int p = 1;

  always_comb m[i][0] = x;
  always_comb m[1][0] = y;

  always_comb m[0][p] = x;
  always_comb m[0][1] = y;
endmodule
