module sv_format_s_leading_zero;
  string formatted;

  initial begin
    formatted = $sformatf("%s", 32'h00006162);
    if (formatted != "ab")
      $fatal(1, "leading zero bytes were not suppressed: <%s>", formatted);

    formatted = $sformatf("%8s", 32'h00006162);
    if (formatted != "      ab")
      $fatal(1, "explicit field width mismatch: <%s>", formatted);

    formatted = $sformatf("%s", "  ab");
    if (formatted != "  ab")
      $fatal(1, "string leading spaces were changed: <%s>", formatted);

    formatted = $sformatf("%s", 32'h00000000);
    if (formatted != "")
      $fatal(1, "zero value was not suppressed: <%s>", formatted);

    $display("PASSED");
  end
endmodule
