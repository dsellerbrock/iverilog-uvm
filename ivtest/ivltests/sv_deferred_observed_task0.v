module t;
  integer observed_value = 0;
  integer pass_calls = 0;
  integer fail_calls = 0;

  task pass_action;
    pass_calls = pass_calls + 1;
    $display("PASS_ACTION value=%0d", observed_value);
  endtask

  task fail_action;
    fail_calls = fail_calls + 1;
    $display("FAIL_ACTION value=%0d", observed_value);
  endtask

  initial begin
    assert #0 (1) pass_action();
    assert #0 (0) else fail_action();
    observed_value <= 42;
    #1;
    if (pass_calls != 1 || fail_calls != 1 || observed_value != 42)
      $fatal(1, "unexpected deferred task results %0d/%0d value=%0d",
             pass_calls, fail_calls, observed_value);
    $display("PASS");
  end
endmodule
