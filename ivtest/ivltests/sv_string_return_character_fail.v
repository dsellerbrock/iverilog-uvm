module sv_string_return_character_fail;
  const string text = "ABC";
  initial text[0] += 1;
endmodule
