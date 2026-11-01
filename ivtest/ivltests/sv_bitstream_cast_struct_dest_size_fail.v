// IEEE 1800-2017/2023 6.24.3: fixed-size unpacked/packed bit-stream types
// with different sizes cannot be explicitly cast.
module test;
  typedef struct { byte first; } one_byte_t;
  one_byte_t value;
  initial value = one_byte_t'(16'h1234);
endmodule
