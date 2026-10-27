module sv_display_explicit_width;
  string actual;

  initial begin
    actual = $sformatf("%3h|%3h|%3h|%02X|%3o|%3b|%h|%0h",
                       32'h5, 32'h100, 32'h1234, 32'h3,
                       32'h5, 32'h5, 32'h5, 32'h5);
    if (actual != "005|100|1234|03|005|101|00000005|5")
      $fatal(1, "explicit radix width: got <%s>", actual);

    $swrite(actual, "%14b|%4h", 8'b00001001, 11'd16);
    if (actual != "00000000001001|0010")
      $fatal(1, "explicit radix field padding: got <%s>", actual);

    $swrite(actual, "%-14b|%-14o|%-14h",
            8'b00001001, 8'b00001001, 8'b00001001);
    if (actual != "00001001      |011           |09            ")
      $fatal(1, "left-justified radix width: got <%s>", actual);

    $display("PASSED");
  end
endmodule
