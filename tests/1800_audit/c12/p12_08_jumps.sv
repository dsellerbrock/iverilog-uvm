module p12_08_jumps;
  int pass, fail;

  task automatic check(input bit ok, input string name);
    if (ok) pass++;
    else begin
      fail++;
      $display("FAIL %s", name);
    end
  endtask

  function automatic int choose(input int value);
    if (value == 2) return 7;
    return -1;
  endfunction

  task automatic early_return(output int value);
    value = 11;
    return;
    value = 99;
  endtask

  initial begin
    int sum, nested_breaks, task_value;

    sum = 0;
    for (int i = 0; i < 6; i++) begin
      if (i == 2) continue;
      if (i == 5) break;
      sum += i;
    end
    check(sum == 8, "continue advances for loop and break exits it");

    nested_breaks = 0;
    for (int i = 0; i < 3; i++) begin
      for (int j = 0; j < 3; j++) begin
        if (j == 1) break;
        nested_breaks++;
      end
    end
    check(nested_breaks == 3, "break exits only the innermost loop");

    check(choose(2) == 7 && choose(0) == -1,
          "return expression exits a value function");
    task_value = 0;
    early_return(task_value);
    check(task_value == 11, "bare return exits a task");

    $display("RESULT pass=%0d fail=%0d", pass, fail);
    if (fail != 0) $fatal(1, "jump checks failed");
  end
endmodule
