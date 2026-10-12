// IEEE 1800-2017/2023 13.5.2 and 6.22.2(c): ref actuals must have
// equivalent types; packed bit and logic arrays are not equivalent.
module sv_ref_argument_type_mismatch_fail;
  logic [31:0] logic_actual;
  bit [31:0] bit_actual;
  logic [31:0] result;

  task automatic accept_task(ref logic [31:0] value);
  endtask

  function automatic logic [31:0] accept_function(ref logic [31:0] value);
    return value;
  endfunction

  initial begin
    accept_task(logic_actual);
    result = accept_function(logic_actual);
    accept_task(bit_actual);
    result = accept_function(bit_actual);
  end
endmodule
