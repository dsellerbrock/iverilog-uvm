module sv_const_string_character_write;
  function automatic string rewrite(input string text);
    string local_text;
    int calls;
    local_text = text;
    local_text[calls++] = "Z";
    local_text[2] = 16'h0159;
    if (calls != 1) return "BAD";
    return local_text;
  endfunction
  function automatic string replace_last(input string text);
    text[2] = "X";
    return text;
  endfunction
  function automatic string nested_local();
    begin : lexical_block
      string text;
      text = "ABC";
      text[1] = "Z";
      return text;
    end
  endfunction
  localparam string FIRST = rewrite("ABC");
  localparam string LAST = replace_last("ABC");
  localparam string NESTED = nested_local();
  initial begin
    if (FIRST != "ZBY" || LAST != "ABX" || NESTED != "AZC")
      $fatal(1, "constant string character write failed: %s/%s/%s", FIRST, LAST, NESTED);
    $display("PASSED");
  end
endmodule
