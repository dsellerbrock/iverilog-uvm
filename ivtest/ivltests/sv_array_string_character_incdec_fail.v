module sv_array_string_character_incdec_fail;
  const string values[2] = '{"ABC","DEF"};
  initial values[0][1]++;
endmodule
