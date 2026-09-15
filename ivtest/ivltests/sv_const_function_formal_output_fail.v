module sv_const_function_formal_output_fail;
  function automatic int prohibited(output int value);
    value = 9;
    return value;
  endfunction
  int value;
  localparam int VALUE = prohibited(value);
endmodule
