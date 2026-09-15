module sv_const_function_formal_ref_fail;
  function automatic int folded;
    int value = 8;
    return prohibited(value);
  endfunction
  function automatic int prohibited(ref int value);
    value += 1;
    return value;
  endfunction
  localparam int VALUE = folded();
endmodule
