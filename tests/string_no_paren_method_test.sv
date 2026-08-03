// IEEE 1800-2017 13.4.2: parentheses may be omitted on a no-argument call.
module string_no_paren_method_test;
  string value = "abcd";
  initial begin
    if (value.len == 4)
      $display("PASS: no-parentheses string method");
    else
      $display("FAIL: value.len=%0d expected=4", value.len);
    $finish;
  end
endmodule
