module issue3034_assert_sensitivity;
  logic condition = 0, pass_guard = 0, fail_guard = 0;
  logic function_condition = 0, function_action = 0;
  integer runs = 0, function_runs = 0;
  integer pass_count = 0, fail_count = 0, function_count = 0;

  function automatic integer check_function();
    assert (function_condition)
      else if (function_action) function_count++;
    return 0;
  endfunction

  always_comb begin
    runs++;
    assert (condition) begin
      if (pass_guard) pass_count++;
    end else begin
      if (fail_guard) fail_count++;
    end
  end

  always_comb begin
    function_runs++;
    void'(check_function());
  end

  initial begin
    #1;
    if (runs != 1 || function_runs != 1) $fatal(1, "startup");
    fail_guard = 1; function_action = 1;
    #1;
    if (runs != 1 || function_runs != 1) $fatal(1, "action sensitivity");
    condition = 1; function_condition = 1;
    #1;
    if (runs != 2 || function_runs != 2) $fatal(1, "condition sensitivity");
    pass_guard = 1;
    #1;
    if (runs != 2) $fatal(1, "pass action sensitivity");
    condition = 0; function_condition = 0;
    #1;
    if (runs != 3 || function_runs != 3 || fail_count != 1 || function_count != 1)
      $fatal(1, "fail action execution");
    condition = 1;
    #1;
    if (runs != 4 || pass_count != 1) $fatal(1, "pass action execution");
    $display("PASSED");
    $finish(0);
  end
endmodule
