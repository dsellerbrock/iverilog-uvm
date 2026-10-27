`default_nettype none
module sv_default_argument_declaration_scope_missing;
  function automatic int f(input int a = 1, input int b = a + 1);
    return b;
  endfunction

  initial $display("%0d", f());
endmodule
`default_nettype wire
