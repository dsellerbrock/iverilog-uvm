module sv_const_array_string_character_incdec_fail;
  string external_words[2];
  function automatic byte folded;
    return external_words[0][0]++;
  endfunction
  localparam byte VALUE = folded();
endmodule
