module sv_const_string_character_incdec_fail;
  string state = "ABC";
  function automatic byte nonlocal_write();
    return state[0]++;
  endfunction
  function automatic byte readonly_write(const ref string text);
    return ++text[0];
  endfunction
  localparam byte NONLOCAL = nonlocal_write();
  localparam byte READONLY = readonly_write("ABC");
endmodule
