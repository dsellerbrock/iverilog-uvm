// IEEE 1800-2017/2023 6.16: only string literals can be assigned to
// integral targets without a cast. A string character is a byte target.
module sv_string_expression_to_byte_fail;
  string a = "xyz";
  string b = "QRS";
  byte c;

  initial begin
    a[0] = b;
    c = b;
  end
endmodule
