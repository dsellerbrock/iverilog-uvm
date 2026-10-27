module sv_function_const_ref_context;
  bit q;
  wire w;

  function automatic bit const_ref_arg(const ref bit value);
    return 1'b1;
  endfunction

  function automatic bit output_arg(output bit value);
    value = 1'b1;
    return 1'b1;
  endfunction

  assign w = const_ref_arg(q);

  initial begin
    #1;
    if (w !== 1'b1) $fatal(1, "const ref function call failed");
    if (output_arg(q) !== 1'b1 || q !== 1'b1)
      $fatal(1, "procedural output function call failed");
    $display("PASS");
  end
endmodule
