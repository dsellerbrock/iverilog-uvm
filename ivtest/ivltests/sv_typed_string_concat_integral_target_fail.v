// IEEE 1800-2017/2023 6.16 and Table 6-9: a string expression is not
// implicitly assignment-compatible with an integral target. In particular,
// a nonconstant replication of string literals is intrinsically string.
module sv_typed_string_concat_integral_target_fail;
  logic [31:0] packed_value;
  int repeat_count = 2;
  string source = "A";

  initial begin
    packed_value = {repeat_count{"AB"}};
    packed_value = {source, "B"};
  end
endmodule
