module sv_const_string_integer_bounds;
  function automatic integer d(input string text); return text.atoi(); endfunction
  function automatic integer h(input string text); return text.atohex(); endfunction
  function automatic integer o(input string text); return text.atooct(); endfunction
  function automatic integer b(input string text); return text.atobin(); endfunction

  parameter string DIRECT_DEC_TEXT = "4294967295";
  parameter string DIRECT_HEX_TEXT = "ffffffff";
  parameter string DIRECT_OCT_TEXT = "37777777777";
  parameter string DIRECT_BIN_TEXT = "11111111111111111111111111111111";
  localparam integer DIRECT_DEC = DIRECT_DEC_TEXT.atoi();
  localparam integer DIRECT_HEX = DIRECT_HEX_TEXT.atohex();
  localparam integer DIRECT_OCT = DIRECT_OCT_TEXT.atooct();
  localparam integer DIRECT_BIN = DIRECT_BIN_TEXT.atobin();
  localparam integer EMPTY = d("");
  localparam integer UNDERSCORES = d("___");
  localparam integer LEADING_UNDERSCORE = d("_1_2");
  localparam integer PLUS = d("+12");
  localparam integer MINUS = d("-12");
  localparam integer PREFIX = h("0x12");
  localparam integer INVALID_DEC = d("12z34");
  localparam integer INVALID_HEX = h("aGf");
  localparam integer INVALID_OCT = o("718");
  localparam integer INVALID_BIN = b("1012");
  localparam integer HIGH_BYTE = d("\20012");
  localparam integer DEC_MAX = d("2147483647");
  localparam integer DEC_SIGN = d("2147483648");
  localparam integer DEC_ONES = d("4294967295");
  localparam integer DEC_WRAP = d("4294967296");
  localparam integer HEX_SIGN = h("80000000");
  localparam integer HEX_WRAP = h("1_00000000");
  localparam integer OCT_ONES = o("37777777777");
  localparam integer BIN_ONES = b("11111111111111111111111111111111");
  localparam integer BIN_WRAP = b("100000000000000000000000000000000");

  initial begin
    string runtime_dec_sign;
    string runtime_dec_ones;
    string runtime_dec_wrap;
    string runtime_hex;
    string runtime_oct;
    string runtime_bin;
    runtime_dec_sign = "2147483648";
    runtime_dec_ones = "4294967295";
    runtime_dec_wrap = "4294967296";
    runtime_hex = "ffffffff";
    runtime_oct = "37777777777";
    runtime_bin = "11111111111111111111111111111111";
    if (EMPTY != 0 || UNDERSCORES != 0 || LEADING_UNDERSCORE != 12 ||
        PLUS != 0 || MINUS != 0 || PREFIX != 0 || INVALID_DEC != 12 ||
        INVALID_HEX != 10 || INVALID_OCT != 8'o71 || INVALID_BIN != 5 ||
        HIGH_BYTE != 0 || DEC_MAX != 32'sh7fffffff ||
        DEC_SIGN != 32'sh80000000 || DEC_ONES != -1 || DEC_WRAP != 0 ||
        HEX_SIGN != 32'sh80000000 || HEX_WRAP != 0 || OCT_ONES != -1 ||
        BIN_ONES != -1 || BIN_WRAP != 0 || DIRECT_DEC != DEC_ONES ||
        DIRECT_HEX != -1 || DIRECT_OCT != OCT_ONES || DIRECT_BIN != BIN_ONES ||
        runtime_dec_sign.atoi() != DEC_SIGN ||
        runtime_dec_ones.atoi() != DEC_ONES || runtime_dec_wrap.atoi() != DEC_WRAP ||
        runtime_hex.atohex() != DIRECT_HEX ||
        runtime_oct.atooct() != OCT_ONES || runtime_bin.atobin() != BIN_ONES)
      $fatal(1, "string integer conversion boundary mismatch");
    $display("PASSED");
  end
endmodule
