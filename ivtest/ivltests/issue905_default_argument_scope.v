module issue905_default_argument_scope;
  int a = 100;

  function automatic int k(input int a = 1, input int b = a + 1);
    return b;
  endfunction

  task automatic check_task(input int a = 1, input int b = a + 1);
    if (b !== 101)
      $fatal(1, "task default used formal a: %0d", b);
  endtask

  initial begin
    if (k() !== 101)
      $fatal(1, "function default used formal a: %0d", k());
    if (k(2) !== 101)
      $fatal(1, "function default used explicit formal a: %0d", k(2));
    check_task();
    check_task(2);

    a = 200;
    if (k() !== 201)
      $fatal(1, "function default was not evaluated at the call: %0d", k());
    if (k(2) !== 201)
      $fatal(1, "function default used explicit formal a: %0d", k(2));

    $display("PASSED");
    $finish;
  end
endmodule
