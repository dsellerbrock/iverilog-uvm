module sv_const_string_character_write_fail;
  string nonlocal = "ABC";
  function automatic string illegal_write();
    nonlocal[0] = "Z";
    return "OK";
  endfunction
  localparam string VALUE = illegal_write();
endmodule
