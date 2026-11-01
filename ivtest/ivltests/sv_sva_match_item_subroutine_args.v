`timescale 1ns/1ps
// IEEE 1800-2017/2023 16.11: sampled sequence locals are passed to
// attached input formals by value; attached calls run for cover and assert.
module sv_sva_match_item_subroutine_args;
  logic clk = 0, start = 0, finish = 0;
  int payload = 0;
  int ref_target = 0;
  int task_calls = 0, function_calls = 0, assertion_calls = 0;
  always #5 clk = ~clk;

  class match_sink;
    int task_calls = 0, function_calls = 0;
    task automatic record_task(input int value);
      if (value !== 17) $fatal(1, "method task value=%0d", value);
      task_calls++;
    endtask
    function automatic void record_function(input int value);
      if (value !== 17) $fatal(1, "method function value=%0d", value);
      if (task_calls != function_calls + 1)
	$fatal(1, "method call order task=%0d function=%0d",
	       task_calls, function_calls);
      function_calls++;
    endfunction
  endclass
  match_sink sink;

  task automatic record_task(input int value);
    if (value !== 17) $fatal(1, "task value=%0d", value);
    task_calls++;
  endtask

  function automatic void record_function(input int value);
    if (value !== 17) $fatal(1, "function value=%0d", value);
    if (task_calls != function_calls + 1)
      $fatal(1, "call order task=%0d function=%0d",
	     task_calls, function_calls);
    function_calls++;
  endfunction

  task automatic record_assertion(input int value);
    if (value !== 23) $fatal(1, "assertion task value=%0d", value);
    assertion_calls++;
  endtask

  task automatic record_ref(ref int value);
    value = 5;
  endtask

  sequence match_with_argument;
    int local_value;
    (start, local_value = payload) ##1
      (finish, record_task(local_value), record_function(local_value),
	 sink.record_task(local_value), sink.record_function(local_value),
	 record_ref(ref_target),
	 $display("match-item-argument=%0d", local_value));
  endsequence

  assert property (@(posedge clk) (1'b1, record_assertion(23)));
  cover property (@(posedge clk) match_with_argument);

  initial begin
    sink = new;
    @(negedge clk); start = 1; payload = 17;
    @(posedge clk); #1; start = 0; finish = 1; payload = 99;
    @(posedge clk); #1;
    if (task_calls != 1 || function_calls != 1
	|| sink.task_calls != 1 || sink.function_calls != 1
	|| assertion_calls != 3 || ref_target != 5)
      $fatal(1, "call counts task=%0d function=%0d method-task=%0d method-function=%0d",
	     task_calls, function_calls, sink.task_calls, sink.function_calls);
    $display("PASSED");
    $finish(0);
  end
endmodule
