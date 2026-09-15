module sv_const_string_character;
  function automatic byte char_at(input string text, input logic [127:0] index);
    string local_text;
    local_text = text;
    return local_text[index];
  endfunction
  function automatic byte signed_char_at(input string text, input logic signed [127:0] index);
    return text[index];
  endfunction

  localparam int FIRST = char_at("ABC", 0);
  localparam int SECOND = char_at("ABC", 2'd1);
  localparam int HIGH = char_at("\200", 0);
  localparam int EMPTY = char_at("", 0);
  localparam int AT_END = char_at("ABC", 3);
  localparam int UNKNOWN = char_at("ABC", 128'bx);
  localparam int MIXED_X = char_at("ABC", {{126{1'b0}}, 2'b1x});
  localparam int WIDE = char_at("ABC", 128'h1_0000000000000000000000000);
  localparam int NEGATIVE = signed_char_at("ABC", -128'sd1);

  initial begin
    string runtime_text;
    logic [127:0] runtime_index;
    runtime_text = "ABC";
    runtime_index = 1;
    if (FIRST != 65 || SECOND != 66 || HIGH != -128 || EMPTY != 0 ||
        AT_END != 0 || UNKNOWN != 65 || MIXED_X != 67 || WIDE != 65 || NEGATIVE != 0 ||
        char_at(runtime_text, runtime_index) != SECOND)
      $fatal(1, "constant/runtime string character mismatch");
    $display("PASSED");
  end
endmodule
