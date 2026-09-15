module sv_array_string_character_compound_fail;
  const string values[2] = '{"ABC","DEF"};
  initial values[0][1] += 1;
endmodule
