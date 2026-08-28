// IEEE 1800-2017/2023 7.6 and 7.7: only the slowest-varying
// unpacked dimension may differ in array kind. The inner queue in int[$][$]
// is part of the element type and is not equivalent to the inner dynamic
// array in int[][]. A fixed `int [2][3]` actual is likewise incompatible:
// after the permitted outer fixed/dynamic difference, its fixed inner array
// is not equivalent to the formal's dynamic inner array. Pin the same rule
// for direct whole-container assignment and every by-value direction in both
// tasks and non-void functions.
module sv_subroutine_nested_container_formal_fail;
  int queue_of_queues[$][$];
  int dynamic_of_dynamic[][];
  int fixed_of_fixed[2][3];
  int result;

  task automatic task_input(input int value[][]);
  endtask

  task automatic task_output(output int value[][]);
    value = new[0];
  endtask

  task automatic task_inout(inout int value[][]);
  endtask

  function automatic int function_input(input int value[][]);
    return value.size();
  endfunction

  function automatic int function_output(output int value[][]);
    value = new[0];
    return value.size();
  endfunction

  function automatic int function_inout(inout int value[][]);
    return value.size();
  endfunction

  initial begin
    task_input(queue_of_queues);
    task_output(queue_of_queues);
    task_inout(queue_of_queues);
    result = function_input(queue_of_queues);
    result = function_output(queue_of_queues);
    result = function_inout(queue_of_queues);
    dynamic_of_dynamic = queue_of_queues;
    queue_of_queues = dynamic_of_dynamic;
    task_input(fixed_of_fixed);
    task_output(fixed_of_fixed);
    task_inout(fixed_of_fixed);
    result = function_input(fixed_of_fixed);
    result = function_output(fixed_of_fixed);
    result = function_inout(fixed_of_fixed);
    dynamic_of_dynamic = fixed_of_fixed;
    fixed_of_fixed = dynamic_of_dynamic;
  end
endmodule
