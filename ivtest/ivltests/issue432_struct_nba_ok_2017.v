// A source always_comb may schedule an NBA through a function. A
// continuous call of the same function is legal until it tries to do so.
module issue432_struct_nba_ok;
  typedef struct { logic value; } value_t;
  bit [1:0] continuous_input, procedural_input;
  bit target;
  value_t continuous_result, procedural_result;

  function automatic value_t sample(input bit [1:0] arg);
    value_t result;
    if (arg[1]) target <= 1'b1;
    result.value = ~arg[0];
    return result;
  endfunction

  assign continuous_result = sample(continuous_input);
  always_comb procedural_result = sample(procedural_input);

  initial begin
    #1;
    if ({continuous_result.value, procedural_result.value, target} !== 3'b110)
      $fatal(1, "incorrect time-zero evaluation");
    continuous_input = 2'b01;
    procedural_input = 2'b11;
    #0;
    if ({continuous_result.value, procedural_result.value, target} !== 3'b000)
      $fatal(1, "incorrect result or NBA updated too early");
    #1;
    if (target !== 1'b1) $fatal(1, "missing procedural NBA");
    $display("PASSED");
  end
endmodule
