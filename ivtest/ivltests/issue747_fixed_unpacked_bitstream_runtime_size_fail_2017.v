module issue747_fixed_unpacked_bitstream_runtime_size_fail;
  typedef byte b4_t[4];
  byte source[];
  b4_t target;
  initial begin
    source = new[3];
    source[0] = 8'h01;
    source[1] = 8'h02;
    source[2] = 8'h03;
    target = b4_t'(source);
  end
endmodule
