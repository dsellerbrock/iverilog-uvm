module issue799_string_format_leading_zero;
  string result;

  initial begin
    result = $sformatf("%s", 32'h00006162);
    if (result != "ab")
      $fatal(1, "leading zero bytes: got [%s], expected [ab]", result);

    result = $sformatf("%s", 32'h20206162);
    if (result != "  ab")
      $fatal(1, "leading space bytes: got [%s], expected [  ab]", result);

    result = $sformatf("%4s", 32'h00006162);
    if (result != "  ab")
      $fatal(1, "explicit width: got [%s], expected [  ab]", result);

    result = $sformatf("%-4s", 32'h00006162);
    if (result != "ab  ")
      $fatal(1, "left justification: got [%s], expected [ab  ]", result);

    result = $sformatf("%s", " ab");
    if (result != " ab")
      $fatal(1, "string argument: got [%s], expected [ ab]", result);

    $display("PASS");
  end
endmodule
