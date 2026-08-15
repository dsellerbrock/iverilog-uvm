// IEEE 1800-2017 13.4.4: a function may spawn processes with
// fork...join_none. The restriction does not apply to task fork...join or
// fork...join_any statements.
module top;
  int module_seen = -1;
  int task_join_seen = -1;
  int task_any_seen = -1;

  task automatic mark(input int value);
    module_seen = value;
  endtask

  task automatic legal_task_join(input int value);
    fork
      task_join_seen = value;
    join
  endtask

  task automatic legal_task_join_any(input int value);
    fork
      task_any_seen = value;
    join_any
    wait fork;
  endtask

  function automatic int legal_function(input int value);
    begin : nested_function_scope
      fork : detached_function_work
        mark(value);
      join_none
    end
    return value + 1;
  endfunction

  class fork_class;
    int seen = -1;

    function int legal_method(input int value);
      fork
        seen = value;
      join_none
      return value + 2;
    endfunction
  endclass

  fork_class obj;
  int function_result;
  int method_result;

  initial begin
    obj = new;

    legal_task_join(30);
    legal_task_join_any(40);
    function_result = legal_function(10);
    method_result = obj.legal_method(20);

    // A join_none child starts when its parent thread next blocks.
    #0;
    wait fork;

    if (function_result != 11 || method_result != 22 ||
        module_seen != 10 || obj.seen != 20 ||
        task_join_seen != 30 || task_any_seen != 40) begin
      $display("FAIL function=%0d method=%0d module=%0d class=%0d join=%0d any=%0d",
               function_result, method_result, module_seen, obj.seen,
               task_join_seen, task_any_seen);
      $finish(1);
    end

    $display("PASS");
  end
endmodule
