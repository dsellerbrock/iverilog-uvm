// IEEE 1800-2017/2023 6.16 and Table 6-9: an integral concatenation is
// not implicitly assignment-compatible with string. An explicit string cast
// is required to request integral-to-string conversion.
module sv_typed_string_concat_integral_fail;
  localparam string BAD = {8'h41, 8'h42};
endmodule
