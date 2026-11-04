// IEEE 1800-2017/2023 6.24.3: fixed unpacked-array struct members retain
// declaration and index order in bit-stream casts.
module issue2497_unpacked_array_struct_bitstream;
  typedef struct { byte a; byte c[2]; } s_t;
  typedef logic [23:0] p_t;
  s_t value, result;
  p_t bits;

  initial begin
    value.a = 8'h12;
    value.c[0] = 8'h34;
    value.c[1] = 8'h56;
    bits = p_t'(value);
    if (bits !== 24'h123456) $fatal(1, "to packed: %h", bits);

    result = s_t'(24'habcdef);
    if (result.a !== 8'hab || result.c[0] !== 8'hcd
        || result.c[1] !== 8'hef)
      $fatal(1, "to struct: %h %h %h", result.a, result.c[0], result.c[1]);
    $display("PASSED");
  end
endmodule
