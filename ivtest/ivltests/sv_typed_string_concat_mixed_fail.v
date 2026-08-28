// IEEE 1800-2017/2023 Table 6-9: when one concatenation operand is a
// string expression, every other operand must be a string expression or a
// string literal. An integral operand requires an explicit string cast.
module sv_typed_string_concat_mixed_fail;
  localparam string PREFIX = "prefix";
  localparam string BAD = {PREFIX, 8'h41};
endmodule
