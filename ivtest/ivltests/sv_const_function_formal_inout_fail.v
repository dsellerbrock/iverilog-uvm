module sv_const_function_formal_inout_fail;
  function automatic int prohibited(inout int value);
    value += 1;
    return value;
  endfunction
  function automatic int folded;
    int value = 8;
    return prohibited(value);
  endfunction
  localparam int VALUE = folded();
endmodule
