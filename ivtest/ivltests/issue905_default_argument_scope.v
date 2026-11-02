class issue905_default_argument_item;
  int value;

  function int get_value();
    return value;
  endfunction

  function int value_or_default(input int arg = get_value());
    return arg;
  endfunction
endclass

module issue905_default_argument_scope;
  int a = 100;
  int task_result;

  function automatic int k(input int a = 1, input int b = a + 1);
    return b;
  endfunction

  task automatic observe(input int a = 1, input int b = a + 1);
    task_result = b;
  endtask

  initial begin
    issue905_default_argument_item first, second;
    first = new;
    second = new;
    first.value = 17;
    second.value = 93;

    if (k() !== 101 || k(2) !== 101)
      $fatal(1, "function default used a formal instead of module a");
    observe();
    if (task_result !== 101)
      $fatal(1, "task default used a formal instead of module a");
    observe(2);
    if (task_result !== 101)
      $fatal(1, "task default changed with an explicit earlier formal");

    a = 200;
    if (k() !== 201 || k(2) !== 201)
      $fatal(1, "function default was not evaluated in declaration scope");
    observe();
    if (task_result !== 201)
      $fatal(1, "task default was not evaluated in declaration scope");

    if (first.value_or_default(41) !== 41
        || second.value_or_default() !== 93
        || first.value_or_default() !== 17)
      $fatal(1, "method default lost its implicit receiver");

    $display("PASSED");
  end
endmodule
