// IEEE 1800-2017/2023 7.9.11 and 10.9: a class handle cannot be implicitly
// converted to an associative-array integral element.
class assoc_explicit_error_token;
endclass

module main;
  assoc_explicit_error_token object_value;
  int values[string];

  initial begin
    object_value = new;
    values = '{"not-an-int":object_value};
  end
endmodule
