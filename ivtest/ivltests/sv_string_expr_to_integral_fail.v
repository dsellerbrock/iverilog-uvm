module sv_string_expr_to_integral_fail;
  string a = "xyz";
  string b = "QRS";
  byte c;

  initial begin
    a[0] = b;
    c = b;
  end
endmodule
