// IEEE 1800-2017/2023 7.6 and 13.5: a queue/dynamic-array output
// copy-out requires equivalent element types. Packed state representation
// and packed width are therefore both strict formal-binding boundaries.
module sv_task_output_container_formal_fail;
  bit [7:0] state_actual[];
  logic [6:0] width_actual[$];

  task automatic build_logic_queue(output logic [7:0] value[$]);
    value.push_back(8'h12);
  endtask

  task automatic build_logic_darray(output logic [7:0] value[]);
    value = new[1];
    value[0] = 8'h34;
  endtask

  initial begin
    build_logic_queue(state_actual);
    build_logic_darray(width_actual);
  end
endmodule
