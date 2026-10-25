module sv_string_integral_implicit_fail;
  string s;
  initial begin
    s = 8'h41;
    s = 16'h4142;
  end
endmodule
