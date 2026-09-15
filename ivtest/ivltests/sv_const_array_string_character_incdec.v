module sv_const_array_string_character_incdec;
  function automatic string folded;
    string words[-1:0];
    int word_index = -1;
    int char_index = 0;
    int old_value;
    int prefix_value;
    words[-1] = "abc";
    words[0] = "keep";
    old_value = words[word_index++][char_index++]++;
    prefix_value = --words[-1][1];
    if (word_index != 0 || char_index != 1
        || old_value != 32'd97 || prefix_value != 32'd97
        || words[0] != "keep") return "BAD";
    if (words[-1][2]-- != "c" || ++words[-1][2] != "c") return "BAD";
    return words[-1];
  endfunction

  function automatic string shared_selector_order;
    string words[2];
    int index = 0;
    byte old_value;
    words[0] = "abc";
    words[1] = "keep";
    old_value = words[index++][index++]++;
    if (index != 2 || old_value != 8'h62 || words[1] != "keep") return "BAD";
    return words[0];
  endfunction

  function automatic string runtime_control;
    string words[-1:0];
    words[-1] = "abc";
    words[-1][0]++;
    --words[-1][1];
    words[-1][2]--;
    ++words[-1][2];
    return words[-1];
  endfunction

  localparam string VALUE = folded();
  localparam string ORDERED = shared_selector_order();
  initial begin
    if (VALUE != "bac" || runtime_control() != "bac"
        || ORDERED != "acc" || shared_selector_order() != "acc")
      $fatal(1, "constant/runtime array character incdec mismatch");
    $display("PASSED");
  end
endmodule
