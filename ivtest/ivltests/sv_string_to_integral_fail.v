// IEEE 1800-2017/2023 6.16: an expression of string type cannot be
// assigned to an integral variable or a selected string character.
module sv_string_to_integral_fail;
  string source = "QRS";
  string target = "xyz";
  byte value = source;

  initial target[0] = source;
endmodule
