module sv_string_character_compound_fail;
  const string text = "ABC";
  initial text[0] += 1;
endmodule
