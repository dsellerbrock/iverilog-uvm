module sv_const_array_string_character_incdec_readonly_fail;
  const string words[2] = '{"a", "b"};
  initial words[0][0]++;
endmodule
