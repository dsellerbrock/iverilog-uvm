// IEEE 1800-2017/2023 Table 6-9 requires a string-replication multiplier
// to have integral type, even though it need not be a constant expression.
module sv_typed_string_concat_repeat_type_fail;
  string multiplier = "2";
  string value;
  initial value = {multiplier{"x"}};
endmodule
