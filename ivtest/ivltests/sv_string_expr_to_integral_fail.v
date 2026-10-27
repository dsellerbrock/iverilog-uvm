// IEEE 1800-2017/2023 6.16: a string expression assigned to a byte,
// including a string character, requires an explicit cast.
module sv_string_expr_to_integral_fail;
  string target = "xyz";
  string source = "QRS";
  byte value = source;

  initial begin
    target[0] = source;
  end
endmodule
