`timescale 1ns/1ps
module issue1383_sequence_method_calls;
  logic clk = 0;
  logic fire = 0;
  always #5 clk = !clk;

  class helper;
    int task_calls = 0;
    int function_calls = 0;

    task show_task();
      task_calls++;
      $display("task-method");
    endtask

    function void show_function();
      function_calls++;
      $display("void-function-method");
    endfunction
  endclass

  helper h;
  sequence calls;
    @(posedge clk) (fire, h.show_task(), h.show_function());
  endsequence

  c: cover property (calls);

  initial begin
    h = new();
    @(negedge clk); fire = 1;
    @(negedge clk); fire = 0;
    repeat (2) @(negedge clk);
    if (h.task_calls != 1 || h.function_calls != 1)
      $fatal(1, "method counts task=%0d function=%0d",
             h.task_calls, h.function_calls);
    $display("PASSED");
    $finish(0);
  end
endmodule
