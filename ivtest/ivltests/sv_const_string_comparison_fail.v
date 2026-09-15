module sv_const_string_comparison_fail;
  function automatic int missing(input string text);
    return text.compare();
  endfunction
  function automatic int extra(input string text);
    return text.icompare("a", "b");
  endfunction
  function automatic int wrong_receiver(input int value);
    return value.compare("a");
  endfunction
  localparam int MISSING = missing("a");
  localparam int EXTRA = extra("a");
  localparam int TYPE = wrong_receiver(1);
endmodule
