// IEEE 1800-2017/2023 6.24.3: unpacked struct members form a bit stream
// in declaration order, with the first member in the most-significant bits.
module sv_bitstream_unpacked_struct_to_packed;
  typedef struct { byte a; byte b; } s_t;
  typedef logic [15:0] p_t;
  s_t value;
  p_t bits;

  initial begin
    value.a = 8'h12;
    value.b = 8'h34;
    bits = p_t'(value);
    if (bits != 16'h1234) $fatal(1, "struct-to-packed=%h", bits);
    $display("PASSED");
  end
endmodule
