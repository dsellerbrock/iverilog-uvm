// IEEE 1800-2017/2023 7.6: the source and destination of an unpacked-array
// copy need the same number of elements in every dimension.
module issue428_uarray_multidim_prefix_fail;
  int a[2][2][3];
  int b[4][3][2];
  initial a[0] = b[1];
endmodule
