module issue799_sformat_leading_zero;
  logic [31:0] packed_value;
  string string_value;

  task automatic check(input string label, input string got,
                      input string expected);
    if (got != expected)
      $fatal(1, "%s: got [%s], expected [%s]", label, got, expected);
  endtask

  initial begin
    packed_value = 32'h00006162;
    string_value = "  ab";

    check("integral constant", $sformatf("%s", 32'h00006162), "ab");
    check("integral variable", $sformatf("%s", packed_value), "ab");
    check("leading ASCII space", $sformatf("%s", 32'h00206162), " ab");
    check("explicit right width", $sformatf("%5s", 32'h00006162), "   ab");
    check("explicit left width", $sformatf("%-5s", 32'h00006162), "ab   ");
    check("zero width", $sformatf("%0s", 32'h00006162), "ab");
    check("string argument", $sformatf("%s", string_value), "  ab");

    $display("PASSED");
    $finish;
  end
endmodule
