// The resolver is pure. Its continuous driver attempts the NBA (13.4.4).
module issue432_nettype_nba;
  typedef struct { bit value; } value_t;
  bit target, trigger;

  function automatic value_t resolve(input value_t drivers[]);
    value_t result;
    result.value = 0;
    foreach (drivers[i]) result.value |= drivers[i].value;
    return result;
  endfunction

  function automatic value_t schedule(input bit arg);
    value_t result;
    if (arg) target <= 1'b1;
    result.value = arg;
    return result;
  endfunction

  nettype value_t resolved_t with resolve;
  resolved_t result;
  assign result = schedule(trigger);
  initial begin
    #1 trigger = 1;
    #1 $display("result=%b target=%b", result.value, target);
  end
endmodule
