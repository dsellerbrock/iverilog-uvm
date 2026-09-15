module sv_const_string_toupper_fail;
  function automatic string bad_arity(input string text);
    return text.toupper(1);
  endfunction
  function automatic string bad_lower_arity(input string text);
    return text.tolower(1);
  endfunction
  function automatic string bad_type(input int value);
    return value.toupper();
  endfunction
  localparam string ARITY = bad_arity("abc");
  localparam string LOWER_ARITY = bad_lower_arity("ABC");
  localparam string TYPE = bad_type(1);
endmodule
