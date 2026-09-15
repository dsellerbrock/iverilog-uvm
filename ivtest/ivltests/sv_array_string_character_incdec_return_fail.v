module sv_array_string_character_incdec_return_fail;
  typedef string arr_t[2];
  function automatic arr_t make;
    byte old;
    make[0] = "ABC";
    old = make[0][1]++;
  endfunction
endmodule
