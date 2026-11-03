// IEEE 1800-2017/2023 6.24.3: fixed-size bit-stream casts require equal
// source and destination widths when either side is unpacked.
module sv_bitstream_fixed_uarray_cast_size_fail;
  typedef byte b3_t[3];
  b3_t bytes;
  logic [31:0] source;
  int value;

  initial begin
    bytes = b3_t'(source);
    value = int'(bytes);
  end
endmodule
