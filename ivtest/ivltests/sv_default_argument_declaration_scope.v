module sv_default_argument_declaration_scope;
  int a = 100;

  function automatic int f(input int a = 1, input int b = a + 1);
    return b;
  endfunction

  task automatic t(input int a = 1, input int b = a + 1);
    if (b != 101)
      $fatal(1, "task default resolved outside declaration scope: %0d", b);
  endtask

  initial begin
    if (f() != 101 || f(2) != 101)
      $fatal(1, "function default resolved outside declaration scope");
    t();
    t(2);
    $display("PASSED");
  end
endmodule
