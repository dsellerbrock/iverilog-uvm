module sv_string_radix_toa;
  string text;
  integer value;
  initial begin
    value = 32'hffffffff;
    text.hextoa(value);
    if (text != "ffffffff" || text.atohex() != value) $fatal(1, "hextoa(-1): %s", text);

    value = 32'h80000000;
    text.hextoa(value);
    if (text != "80000000" || text.atohex() != value) $fatal(1, "hextoa(min): %s", text);

    value = 32'hdeadbeef;
    text.hextoa(value);
    if (text != "deadbeef" || text.atohex() != value) $fatal(1, "hextoa(pattern): %s", text);

    value = 32'o20000000000;
    text.octtoa(value);
    if (text != "20000000000" || text.atooct() != value) $fatal(1, "octtoa(min): %s", text);

    value = 32'h80000000;
    text.bintoa(value);
    if (text != "10000000000000000000000000000000" || text.atobin() != value)
      $fatal(1, "bintoa(min): %s", text);

    text.itoa(value);
    if (text != "-2147483648") $fatal(1, "itoa(min): %s", text);
    $display("PASSED");
  end
endmodule
