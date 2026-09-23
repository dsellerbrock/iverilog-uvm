// Without -gcommercial-unsafe, native queue value formals retain IEEE
// 1800-2017/2023 element-type equivalence checks in both directions.
module sv_commercial_unsafe_strict_fail;
  logic [7:0] logic_q[$];

  task automatic task_input(input bit [7:0] values[$]);
  endtask

  task automatic task_output(output bit [7:0] values[$]);
    values.delete();
  endtask

  function automatic void function_input(input bit [7:0] values[$]);
  endfunction

  function automatic void function_output(output bit [7:0] values[$]);
    values.delete();
  endfunction

  initial begin
    task_input(logic_q);
    task_output(logic_q);
    function_input(logic_q);
    function_output(logic_q);
  end
endmodule
