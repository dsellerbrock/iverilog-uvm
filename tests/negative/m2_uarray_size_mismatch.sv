// NEGATIVE test: whole-array assignment between unpacked arrays of
// different element counts is not assignment compatible
// (IEEE 1800-2017 7.6, 6.22.2). Expected: compilation FAILS.
module m2_uarray_size_mismatch;
  int a[4];
  int b[5];
  initial begin
    a = b;
  end
endmodule
