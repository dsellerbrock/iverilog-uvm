module sv_const_string_substr;
  function automatic string slice(input string text, input int first, input int last);
    string local_text;
    string saved;
    string result;
    local_text = text;
    saved = local_text;
    result = local_text.substr(first, last);
    if (local_text != saved) return "BAD-SUBSTR-MUTATION";
    return result;
  endfunction

  localparam string MIDDLE = slice("ABCDE", 1, 3);
  localparam string FULL = slice("ABCDE", 0, 4);
  localparam string SINGLE = slice("ABCDE", 4, 4);
  localparam string REPEAT = slice(slice("012345", 1, 4), 1, 2);
  localparam string HIGH = slice("A\200\377Z", 1, 2);

  initial begin
    string runtime_text;
    string runtime_result;
    runtime_text = "ABCDE";
    runtime_result = runtime_text.substr(1, 3);
    if (MIDDLE != "BCD" || FULL != "ABCDE" || SINGLE != "E" ||
        REPEAT != "23" || HIGH != "\200\377" ||
        runtime_result != MIDDLE || runtime_text != "ABCDE")
      $fatal(1, "constant/runtime substr mismatch");
    $display("PASSED");
  end
endmodule
