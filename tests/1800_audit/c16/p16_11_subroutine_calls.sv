module test;
  logic clk = 0, a = 0, b = 0;
  int function_calls = 0, task_calls = 0;
  int argument_calls = 0, captured_value = 0;
  always #5 clk = ~clk;

  function automatic void mark_function();
    function_calls++;
  endfunction

  task automatic mark_task();
    task_calls++;
  endtask

  task automatic mark_argument(int value);
    argument_calls++;
    captured_value = value;
  endtask

  sequence s_system_task;
    @(posedge clk) (a, $display("MATCH: system task"));
  endsequence
  cover property (s_system_task);

  sequence s_void_function;
    @(posedge clk) (a, mark_function());
  endsequence
  cover property (s_void_function);

  sequence s_user_task;
    @(posedge clk) (b, mark_task());
  endsequence
  cover property (s_user_task);

  sequence s_local_argument;
    int value;
    @(posedge clk) (a, value = 42) ##1 (b, mark_argument(value));
  endsequence
  cover property (s_local_argument);

  initial begin
    @(negedge clk); a = 1;
    @(negedge clk); a = 0; b = 1;
    @(negedge clk); b = 0;
    repeat (2) @(negedge clk);
    if (function_calls != 1 || task_calls != 1 ||
        argument_calls != 1 || captured_value != 42)
      $fatal(1, "§16.11 calls: function=%0d task=%0d arg=%0d value=%0d",
             function_calls, task_calls, argument_calls, captured_value);
    $display("PASSED: §16.11 attached subroutine calls");
    $finish(0);
  end
endmodule
