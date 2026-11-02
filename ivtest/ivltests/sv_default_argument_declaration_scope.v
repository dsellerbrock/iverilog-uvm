module sv_default_argument_declaration_scope;
  int a = 100;

  function automatic int k(input int a = 1, input int b = a + 1);
    return b;
  endfunction

  initial begin
    if (k() !== 101)
      $fatal(1, "default argument used formal a instead of module a: %0d", k());
    if (k(2) !== 101)
      $fatal(1, "default argument used the earlier actual: %0d", k(2));
    if (k(2, 7) !== 7)
      $fatal(1, "explicit argument changed: %0d", k(2, 7));
    $display("PASSED");
  end
endmodule
