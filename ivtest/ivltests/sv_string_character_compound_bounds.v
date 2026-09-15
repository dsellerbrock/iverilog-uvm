module sv_string_character_compound_bounds;
  string text = "ABC";
  int calls;
  logic unknown;
  logic [127:0] wide_unknown;
  logic [127:0] wide_invalid;
  logic [127:0] mixed_index;
  logic [127:0] high_index;
  string empty = "";
  int rhs_calls;
  function automatic int index_once(input int value); calls++; return value; endfunction
  function automatic logic [127:0] wide_index_once(input logic [127:0] value);
    calls++; return value;
  endfunction
  function automatic int rhs_once(); rhs_calls++; return 1; endfunction
  initial begin
    text[index_once(-1)] += 1;
    text[index_once(99)] ^= 8'hff;
    unknown = 1'bx;
    text[index_once(unknown)] += 1;
    if (text != "BBC" || calls != 3)
      $fatal(1, "two-state int conversion mismatch text=%s calls=%0d", text, calls);
    wide_unknown = 'x;
    wide_invalid = {128{1'b1}};
    text[wide_index_once(wide_unknown)] += 1;
    text[wide_index_once(wide_invalid)] -= 1;
    if (text != "CBC" || calls != 5)
      $fatal(1, "int selector conversion mismatch text=%s calls=%0d", text, calls);
    mixed_index = '0;
    mixed_index[1:0] = 2'b1x;
    text[wide_index_once(mixed_index)] += rhs_once();
    high_index = '0;
    high_index[100] = 1'b1;
    text[wide_index_once(high_index)] += rhs_once();
    empty[wide_index_once(0)] += rhs_once();
    if (text != "DBD" || empty != "" || calls != 8 || rhs_calls != 3)
      $fatal(1, "selector/RHS capture mismatch text=%s calls=%0d rhs=%0d",
             text, calls, rhs_calls);
    text[1] &= 0;
    if (text != "DBD") $fatal(1, "zero putc changed text=%s", text);
    $display("PASSED");
  end
endmodule
