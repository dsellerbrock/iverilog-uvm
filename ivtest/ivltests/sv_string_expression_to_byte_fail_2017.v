module sv_string_expression_to_byte_fail_2017;
  string a = "xyz";
  string b = "QRS";
  byte c;
  initial begin
    a[0] = b;
    c = b;
  end
endmodule
