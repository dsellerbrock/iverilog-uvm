module sv_const_string_integer_fail;
  function automatic integer bad_arity(input string text);
    return text.atoi(1);
  endfunction
  function automatic integer bad_hex_arity(input string text);
    return text.atohex(1);
  endfunction
  function automatic integer wrong_receiver(input int value);
    return value.atobin();
  endfunction
  localparam integer ARITY = bad_arity("1");
  localparam integer HEX_ARITY = bad_hex_arity("f");
  localparam integer TYPE = wrong_receiver(1);
endmodule
