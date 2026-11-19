// The union member makes this a behavioral continuous assignment.
// The nested call still originates from a continuous assignment (13.4.4).
module issue432_union_nba;
  union { bit member; int other; } u;
  bit target, result;

  function automatic bit schedule(input bit arg);
    if (arg) target <= 1'b1;
    return arg;
  endfunction

  function automatic bit outer(input bit arg);
    return schedule(arg);
  endfunction

  assign result = outer(u.member);
  initial begin
    u.member = 0;
    #1 u.member = 1;
    #1 $display("result=%b target=%b", result, target);
  end
endmodule
