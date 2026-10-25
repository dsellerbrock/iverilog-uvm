module top;
  string str;

  function automatic string hex_constant(input integer value);
    string result;
    result.hextoa(value);
    return result;
  endfunction

  localparam string CONST_HEX = hex_constant(32'hdeadbeef);

  initial begin
    if (CONST_HEX != "deadbeef") $fatal(1, "constant hextoa: %s", CONST_HEX);

    str.hextoa(255);
    if (str != "ff") $fatal(1, "positive hextoa: %s", str);
    str.hextoa(-1);
    if (str != "ffffffff") $fatal(1, "negative hextoa: %s", str);
    if (str.atohex() !== 32'hffffffff) $fatal(1, "atohex round trip");
    str.hextoa(32'h80000000);
    if (str != "80000000") $fatal(1, "high-bit hextoa: %s", str);
    str.hextoa(32'hdeadbeef);
    if (str != "deadbeef") $fatal(1, "pattern hextoa: %s", str);

    str.octtoa(-1);
    if (str != "37777777777") $fatal(1, "negative octtoa: %s", str);
    str.octtoa(32'o20000000000);
    if (str != "20000000000") $fatal(1, "high-bit octtoa: %s", str);

    str.bintoa(-1);
    if (str != "11111111111111111111111111111111")
      $fatal(1, "negative bintoa: %s", str);
    str.bintoa(32'h80000000);
    if (str != "10000000000000000000000000000000")
      $fatal(1, "high-bit bintoa: %s", str);

    str.itoa(-1);
    if (str != "-1") $fatal(1, "itoa changed: %s", str);
    $display("PASSED");
  end
endmodule
