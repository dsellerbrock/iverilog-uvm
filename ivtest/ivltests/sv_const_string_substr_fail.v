module sv_const_string_substr_fail;
  function automatic string missing(input string text);
    return text.substr(0);
  endfunction
  function automatic string extra(input string text);
    return text.substr(0, 1, 2);
  endfunction
  function automatic string wrong_receiver(input int value);
    return value.substr(0, 1);
  endfunction
  localparam string MISSING = missing("abc");
  localparam string EXTRA = extra("abc");
  localparam string TYPE = wrong_receiver(1);
endmodule
