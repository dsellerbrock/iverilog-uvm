module sv_const_string_character_incdec_bounds;
  function automatic string bytes();
    string text;
    int a;
    int b;
    int c;
    text = "\177\200\377";
    a = ++text[0];
    b = --text[1];
    c = text[2]++;
    if (a != -128 || b != 127 || c != -1) return "BAD-WIDTH";
    return text;
  endfunction
  function automatic string indexed(input string text,
                                    input logic signed [127:0] index,
                                    input bit prefix);
    byte result;
    result = prefix ? ++text[index] : text[index]++;
    return {text, string'(result)};
  endfunction

  localparam string WRAP = bytes();
  localparam string NEGATIVE = indexed("ABC", -1, 1);
  localparam string AT_END = indexed("ABC", 3, 0);
  localparam string EMPTY = indexed("", 0, 1);
  localparam string UNKNOWN = indexed("ABC", 128'bx, 1);
  localparam string Z_INDEX = indexed("ABC", 128'bz, 0);
  localparam string MIXED_X = indexed("ABCDE", {{126{1'b0}}, 2'b1x}, 1);
  localparam string WIDE = indexed("ABC", 128'h1_0000000000000000000000000, 0);

  initial begin
    if (WRAP != "\200\177\377" ||
        NEGATIVE != {"ABC", string'(8'h01)} || AT_END != "ABC" ||
        EMPTY != string'(8'h01) || UNKNOWN != "BBCB" ||
        Z_INDEX != "BBCA" || MIXED_X != "ABDDED" || WIDE != "BBCA")
      $fatal(1, "string character incdec boundary mismatch");
    $display("PASSED");
  end
endmodule
