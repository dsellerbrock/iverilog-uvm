module sv_function_copyout_context_fail;
  bit q;
  wire w, w_default;

  function automatic bit output_arg(output bit value);
    value = 1'b0;
    return 1'b1;
  endfunction

  function automatic bit inout_arg(inout bit value);
    value = 1'b0;
    return 1'b1;
  endfunction

  function automatic bit ref_arg(ref bit value);
    value = 1'b0;
    return 1'b1;
  endfunction

  assign w = output_arg(q);

  initial @(inout_arg(q)) ;

  initial assign q = ref_arg(q);

  function automatic bit default_ref(input bit value = ref_arg(q));
    return value;
  endfunction

  assign w_default = default_ref();
endmodule
