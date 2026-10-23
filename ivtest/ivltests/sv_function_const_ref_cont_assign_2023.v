module sv_function_const_ref_cont_assign;
  bit q;
  wire w;

  function automatic bit f(const ref bit value);
    return 1'b1;
  endfunction

  function automatic bit g(output bit value);
    value = 1'b0;
    return 1'b1;
  endfunction

  assign w = f(q);

  initial begin
    #1;
    if (w !== 1'b1) $fatal(1, "const ref function call failed");
    if (g(q) !== 1'b1 || q !== 1'b0)
      $fatal(1, "procedural output function call failed");
    $display("PASS");
  end
endmodule
