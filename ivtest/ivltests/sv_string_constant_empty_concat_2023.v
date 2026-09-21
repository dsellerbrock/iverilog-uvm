module test;
  string constant_value;
  string empty_value;
  string left = "ab";
  string right = "cd";
  string concat_value;
  logic [23:0] packed_value = 24'h414243;
  string converted_value;
  string expected_value;

  assign constant_value = "constant";
  assign empty_value = "";
  assign concat_value = {left, ":", right};
  assign converted_value = string'(packed_value);

  initial begin
    #1;
    if (constant_value != "constant") $fatal(1, "constant: %s", constant_value);
    if (empty_value != "") $fatal(1, "empty: %s", empty_value);
    if (concat_value != "ab:cd") $fatal(1, "concat initial: %s", concat_value);
    expected_value = string'(packed_value);
    if (converted_value != expected_value)
      $fatal(1, "conversion initial: %s", converted_value);
    left = "longer";
    right = "";
    packed_value = 24'h58595a;
    #1;
    if (concat_value != "longer:") $fatal(1, "concat resized: %s", concat_value);
    expected_value = string'(packed_value);
    if (converted_value != expected_value)
      $fatal(1, "conversion update: %s", converted_value);
    $display("PASS string constant empty concat");
  end
endmodule
