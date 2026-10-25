module sv_always_comb_overlapping_writers_scalar;
  logic shared, a, b;

  always_comb shared = a;
  always_comb shared = b;
endmodule
