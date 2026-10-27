// IEEE 1800-2023 §6.22.2(d): equal flattened counts do not make these types equivalent.
module sv_multidimensional_array_equality_shape_err;
  int a [2][3];
  int b [3][2];
  int c [6];
  int d [2][3];

  initial begin
    if (a == b) $display("unexpected 2x3/3x2 equality");
    if (a != c) $display("unexpected 2x3/flat inequality");
  end
endmodule
