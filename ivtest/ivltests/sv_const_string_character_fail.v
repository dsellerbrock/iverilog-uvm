module sv_const_string_character_fail;
  string nonconstant = "A";
  function automatic byte illegal_constant_read();
    return nonconstant[0];
  endfunction
  localparam byte VALUE = illegal_constant_read();
endmodule
