module sv_const_string_array_method_argument_fail;
  function automatic int folded;
    string words[1];
    string argument = "abc";
    words[0].itoa(argument);
    return 1;
  endfunction
  localparam int VALUE = folded();
endmodule
