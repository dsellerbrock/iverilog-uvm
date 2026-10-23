module sv_always_comb_longest_static_prefix_control;
  logic [7:0] m [0:1][0:1];
  logic [7:0] x, y;
  localparam int p = 1;

  always_comb m[0][p] = x;
  always_comb m[1][0] = y;

  initial begin
    x = 8'h11;
    y = 8'h22;
    #1 $display("L1 %h %h", m[0][1], m[1][0]);
  end
endmodule
