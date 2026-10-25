// IEEE 1800-2017/2023 9.2.2.2 and 11.5.3: a dynamic first index leaves
// the whole unpacked array as the longest static prefix.
module sv_always_comb_overlapping_writers_dynamic;
  logic [7:0] data [0:1][0:1];
  logic a, b;
  integer index;

  always_comb data[index][0] = a;
  always_comb data[1][0] = b;
endmodule
