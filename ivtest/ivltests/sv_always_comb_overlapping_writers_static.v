// A constant localparam index has the same longest static prefix as a
// literal index to the same unpacked-array word (IEEE 1800-2017/2023 11.5.3).
module sv_always_comb_overlapping_writers_static;
  logic [7:0] data [0:1][0:1];
  logic a, b;
  localparam int p = 1;

  always_comb data[0][p] = a;
  always_comb data[0][1] = b;
endmodule
