module issue747_fixed_unpacked_bitstream_size_fail;
  typedef byte b3_t[3];
  b3_t bytes;
  int packed_value;
  initial begin
    bytes = b3_t'(32'h01020304);
    packed_value = int'(bytes);
  end
endmodule
