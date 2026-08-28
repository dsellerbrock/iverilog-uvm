// IEEE 1800-2017/2023 7.6, 13.4.2 and 13.5: non-void function
// output/inout queue/dynamic-array formals require equivalent element types.
// State representation and packed width remain strict binding boundaries.
module sv_nonvoid_function_container_formal_fail;
  bit [7:0] output_state_actual[];
  logic [6:0] output_width_actual[$];
  bit [7:0] inout_state_actual[];
  logic [6:0] inout_width_actual[$];
  int result;

  function automatic int output_logic_queue(output logic [7:0] value[$]);
    value.push_back(8'h12);
    return value.size();
  endfunction

  function automatic int output_logic_darray(output logic [7:0] value[]);
    value = new[1];
    value[0] = 8'h34;
    return value.size();
  endfunction

  function automatic int inout_logic_queue(inout logic [7:0] value[$]);
    value.push_back(8'h56);
    return value.size();
  endfunction

  function automatic int inout_logic_darray(inout logic [7:0] value[]);
    int initial_size = value.size();
    value = new[initial_size + 1](value);
    value[initial_size] = 8'h78;
    return value.size();
  endfunction

  initial begin
    result = output_logic_queue(output_state_actual);
    result = output_logic_darray(output_width_actual);
    result = inout_logic_queue(inout_state_actual);
    result = inout_logic_darray(inout_width_actual);
  end
endmodule
