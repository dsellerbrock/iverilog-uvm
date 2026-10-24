module sv_function_output_arg_cont_assign_fail;
  reg q;
  wire w;

  function automatic bit f(output bit value);
    value = 1'b0;
    return 1'b1;
  endfunction

  assign w = f(q);
endmodule
