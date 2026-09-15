module sv_const_string_character_incdec;
  function automatic string mutate(input string text);
    byte post_inc;
    byte pre_inc;
    byte post_dec;
    byte pre_dec;
    int calls;
    post_inc = text[calls++]++;
    pre_inc = ++text[1];
    post_dec = text[2]--;
    pre_dec = --text[3];
    if (calls != 1 || post_inc != 66 || pre_inc != 68 ||
        post_dec != 68 || pre_dec != 68)
      return "BAD-RESULT";
    return text;
  endfunction
  function automatic string mutate_return(input string text);
    byte old_value;
    mutate_return = text;
    old_value = mutate_return[0]++;
    if (old_value != 65) return "BAD-RETURN-RESULT";
  endfunction
  function automatic string recursive(input int depth, input string text);
    byte updated;
    updated = ++text[0];
    if (updated != (depth ? 66 : 67)) return "BAD-RECURSIVE-RESULT";
    return depth ? recursive(depth-1, text) : text;
  endfunction

  localparam string FOUR = mutate("BCDE");
  localparam string RETURNED = mutate_return("ABC");
  localparam string RECURSIVE = recursive(1, "ABC");
  localparam string ISOLATED = recursive(1, "ABC");
  initial begin
    string runtime_text;
    byte runtime_old;
    runtime_text = "ABC";
    runtime_old = runtime_text[0]++;
    if (FOUR != "CDCD" || RETURNED != "BBC" ||
        RECURSIVE != "CBC" || ISOLATED != "CBC" ||
        runtime_old != 65 || runtime_text != "BBC")
      $fatal(1, "constant/runtime string character incdec mismatch");
    $display("PASSED");
  end
endmodule
