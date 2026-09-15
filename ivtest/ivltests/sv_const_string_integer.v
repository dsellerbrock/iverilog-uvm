module sv_const_string_integer;
  function automatic integer decimal(input string text);
    string saved;
    integer result;
    saved = text;
    result = text.atoi();
    if (text != saved) return 32'sh80000000;
    return result;
  endfunction
  function automatic integer hexadecimal(input string text);
    return text.atohex();
  endfunction
  function automatic integer octal(input string text);
    return text.atooct();
  endfunction
  function automatic integer binary(input string text);
    return text.atobin();
  endfunction

  parameter string DIRECT_TEXT = "f_Fg";
  localparam integer DIRECT_HEX = DIRECT_TEXT.atohex();
  localparam integer D = decimal("1_23x9");
  localparam integer H = hexadecimal("f_Fg");
  localparam integer O = octal("7_1_8");
  localparam integer B = binary("10_1x");
  localparam integer REPEAT = decimal("42") + decimal("42");

  initial begin
    string runtime_text;
    string runtime_hex;
    string runtime_oct;
    string runtime_bin;
    runtime_text = "1_23x9";
    runtime_hex = "f_Fg";
    runtime_oct = "7_1_8";
    runtime_bin = "10_1x";
    if (D != 123 || H != 255 || O != 8'o71 || B != 5 || REPEAT != 84 ||
        DIRECT_HEX != H || runtime_text.atoi() != D ||
        runtime_hex.atohex() != H || runtime_oct.atooct() != O ||
        runtime_bin.atobin() != B || runtime_text != "1_23x9" ||
        runtime_hex != "f_Fg" || runtime_oct != "7_1_8" ||
        runtime_bin != "10_1x")
      $fatal(1, "constant/runtime string integer conversion mismatch");
    $display("PASSED");
  end
endmodule
