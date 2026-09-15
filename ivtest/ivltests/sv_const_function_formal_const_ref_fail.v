module sv_const_function_formal_const_ref_fail;
  function automatic int prohibited(const ref int value);
    return value + 1;
  endfunction
  function automatic int folded;
    int value = 8;
    return prohibited(value);
  endfunction
  localparam int VALUE = folded();
endmodule
