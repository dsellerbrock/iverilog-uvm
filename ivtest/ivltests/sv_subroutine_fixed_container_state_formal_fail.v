// IEEE 1800-2017/2023 7.6 and 13.5: a native task or function may bind a
// fixed unpacked-array actual to a queue/dynamic-array formal only when the
// element types are equivalent. The narrow bit/logic conversion supported
// for ordinary cross-kind assignment is not a formal-binding relaxation.
module sv_subroutine_fixed_container_state_formal_fail;
  bit   [7:0] bit_fixed[3:5];
  logic [7:0] logic_fixed[5:3];
  int result;

  task automatic task_logic_input(input logic [7:0] value[]);
  endtask

  task automatic task_logic_output(output logic [7:0] value[]);
    value = new[3];
  endtask

  task automatic task_logic_inout(inout logic [7:0] value[]);
  endtask

  function automatic int function_logic_input(input logic [7:0] value[]);
    return value.size();
  endfunction

  function automatic int function_logic_output(output logic [7:0] value[]);
    value = new[3];
    return value.size();
  endfunction

  function automatic int function_logic_inout(inout logic [7:0] value[]);
    return value.size();
  endfunction

  task automatic task_bit_input(input bit [7:0] value[]);
  endtask

  task automatic task_bit_output(output bit [7:0] value[]);
    value = new[3];
  endtask

  task automatic task_bit_inout(inout bit [7:0] value[]);
  endtask

  function automatic int function_bit_input(input bit [7:0] value[]);
    return value.size();
  endfunction

  function automatic int function_bit_output(output bit [7:0] value[]);
    value = new[3];
    return value.size();
  endfunction

  function automatic int function_bit_inout(inout bit [7:0] value[]);
    return value.size();
  endfunction

  initial begin
    task_logic_input(bit_fixed);
    task_logic_output(bit_fixed);
    task_logic_inout(bit_fixed);
    result = function_logic_input(bit_fixed);
    result = function_logic_output(bit_fixed);
    result = function_logic_inout(bit_fixed);

    task_bit_input(logic_fixed);
    task_bit_output(logic_fixed);
    task_bit_inout(logic_fixed);
    result = function_bit_input(logic_fixed);
    result = function_bit_output(logic_fixed);
    result = function_bit_inout(logic_fixed);
  end

  task automatic task_logic_queue_input(input logic [7:0] value[$]);
  endtask

  task automatic task_logic_queue_output(output logic [7:0] value[$]);
  endtask

  task automatic task_logic_queue_inout(inout logic [7:0] value[$]);
  endtask

  function automatic int function_logic_queue_input(
      input logic [7:0] value[$]);
    return 0;
  endfunction

  function automatic int function_logic_queue_output(
      output logic [7:0] value[$]);
    return 0;
  endfunction

  function automatic int function_logic_queue_inout(
      inout logic [7:0] value[$]);
    return 0;
  endfunction

  task automatic task_bit_queue_input(input bit [7:0] value[$]);
  endtask

  task automatic task_bit_queue_output(output bit [7:0] value[$]);
  endtask

  task automatic task_bit_queue_inout(inout bit [7:0] value[$]);
  endtask

  function automatic int function_bit_queue_input(input bit [7:0] value[$]);
    return 0;
  endfunction

  function automatic int function_bit_queue_output(output bit [7:0] value[$]);
    return 0;
  endfunction

  function automatic int function_bit_queue_inout(inout bit [7:0] value[$]);
    return 0;
  endfunction

  initial begin
    task_logic_queue_input(bit_fixed);
    task_logic_queue_output(bit_fixed);
    task_logic_queue_inout(bit_fixed);
    result = function_logic_queue_input(bit_fixed);
    result = function_logic_queue_output(bit_fixed);
    result = function_logic_queue_inout(bit_fixed);

    task_bit_queue_input(logic_fixed);
    task_bit_queue_output(logic_fixed);
    task_bit_queue_inout(logic_fixed);
    result = function_bit_queue_input(logic_fixed);
    result = function_bit_queue_output(logic_fixed);
    result = function_bit_queue_inout(logic_fixed);
  end
endmodule
