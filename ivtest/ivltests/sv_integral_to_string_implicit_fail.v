module sv_integral_to_string_implicit_fail;
  string value;
  logic [15:0] packed_value;
  typedef string string_t;

  initial begin
    value = 8'h41;
    value = packed_value;
    value = string'(packed_value);
    value = string_t'(packed_value);
    value = "A";
    value = {"H", ""};
  end
endmodule
