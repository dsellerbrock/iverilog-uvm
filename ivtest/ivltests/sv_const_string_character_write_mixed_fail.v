module sv_const_string_character_write_mixed_fail;
  string storage = "ABC";
  function automatic string mutate_nonlocal();
    storage[0] = "Z";
    return "OK";
  endfunction
  initial void'(mutate_nonlocal());
  localparam string VALUE = mutate_nonlocal();
endmodule
