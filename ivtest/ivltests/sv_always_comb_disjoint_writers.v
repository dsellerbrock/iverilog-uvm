// Independent constant elements and dynamic writes under distinct static
// row prefixes do not overlap (IEEE 1800-2017/2023 9.2.2.2 and 11.5.3).
module sv_always_comb_disjoint_writers;
  logic [7:0] constant_data [0:1][0:1];
  logic [7:0] dynamic_data [0:1][0:1];
  logic a, b, c, d;
  integer i, j;
  localparam int p = 1;

  always_comb constant_data[0][p] = a;
  always_comb constant_data[1][0] = b;
  always_comb dynamic_data[1][i] = c;
  always_comb dynamic_data[0][j] = d;

  initial begin
    #1;
    $display("PASSED");
    $finish(0);
  end
endmodule
