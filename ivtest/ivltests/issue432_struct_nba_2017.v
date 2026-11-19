// A continuous assignment to an unpacked struct cannot schedule an NBA (13.4.4).
module issue432_struct_nba;
  typedef struct { bit value; } value_t;
  bit target, trigger;
  value_t result;

  function automatic value_t schedule(input bit arg);
    value_t tmp;
    if (arg) target <= 1'b1;
    tmp.value = arg;
    return tmp;
  endfunction

  assign result = schedule(trigger);
  initial begin
    #1 trigger = 1;
    #1 $display("result=%b target=%b", result.value, target);
  end
endmodule
