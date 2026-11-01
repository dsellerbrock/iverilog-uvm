module issue730_string_toa;
  function automatic string hex_text(input integer value);
    string result;
    result.hextoa(value);
    return result;
  endfunction

  function automatic string oct_text(input integer value);
    string result;
    result.octtoa(value);
    return result;
  endfunction

  function automatic string bin_text(input integer value);
    string result;
    result.bintoa(value);
    return result;
  endfunction

  function automatic string dec_text(input integer value);
    string result;
    result.itoa(value);
    return result;
  endfunction

  localparam string CONST_HEX_NEG1 = hex_text(-1);
  localparam string CONST_HEX_SIGN = hex_text(32'h80000000);
  localparam string CONST_HEX_DEAD = hex_text(32'hdeadbeef);
  localparam string CONST_OCT_NEG1 = oct_text(-1);
  localparam string CONST_OCT_SIGN = oct_text(32'h80000000);
  localparam string CONST_BIN_NEG1 = bin_text(-1);
  localparam string CONST_BIN_SIGN = bin_text(32'h80000000);
  localparam string CONST_DEC_NEG1 = dec_text(-1);

  integer errors;

  task automatic check(input bit condition, input string label);
    if (!condition) begin
      $display("FAIL: %s", label);
      errors = errors + 1;
    end
  endtask

  initial begin
    string value;

    errors = 0;
    check(CONST_HEX_NEG1 == "ffffffff", "constant hextoa(-1)");
    check(CONST_HEX_SIGN == "80000000", "constant hextoa(sign bit)");
    check(CONST_HEX_DEAD == "deadbeef", "constant hextoa(deadbeef)");
    check(CONST_OCT_NEG1 == "37777777777", "constant octtoa(-1)");
    check(CONST_OCT_SIGN == "20000000000", "constant octtoa(sign bit)");
    check(CONST_BIN_NEG1 == "11111111111111111111111111111111",
          "constant bintoa(-1)");
    check(CONST_BIN_SIGN == "10000000000000000000000000000000",
          "constant bintoa(sign bit)");
    check(CONST_DEC_NEG1 == "-1", "constant itoa remains signed decimal");

    value.hextoa(-1);
    check(value == "ffffffff", "runtime hextoa(-1)");
    check(value.atohex() == -1, "runtime hex round trip(-1)");
    value.hextoa(32'h80000000);
    check(value == "80000000", "runtime hextoa(sign bit)");
    check(value.atohex() == 32'sh80000000, "runtime hex round trip(sign bit)");
    value.hextoa(32'hdeadbeef);
    check(value == "deadbeef", "runtime hextoa(deadbeef)");
    check(value.atohex() == 32'shdeadbeef, "runtime hex round trip(deadbeef)");

    value.octtoa(-1);
    check(value == "37777777777", "runtime octtoa(-1)");
    check(value.atooct() == -1, "runtime octal round trip(-1)");
    value.octtoa(32'h80000000);
    check(value == "20000000000", "runtime octtoa(sign bit)");
    check(value.atooct() == 32'sh80000000, "runtime octal round trip(sign bit)");

    value.bintoa(-1);
    check(value == "11111111111111111111111111111111", "runtime bintoa(-1)");
    check(value.atobin() == -1, "runtime binary round trip(-1)");
    value.bintoa(32'h80000000);
    check(value == "10000000000000000000000000000000", "runtime bintoa(sign bit)");
    check(value.atobin() == 32'sh80000000, "runtime binary round trip(sign bit)");

    value.itoa(-1);
    check(value == "-1", "itoa remains signed decimal");

    if (errors != 0) $fatal(1, "issue 730: %0d checks failed", errors);
    $display("PASSED");
  end
endmodule
