// A function that schedules an NBA is a legal run-time function, but it is
// not a constant function. Compile-time evaluation must reject it rather than
// treating the scheduled update as a no-op.
module sv_function_nba_const_fail;
  logic side_effect;

  function int value();
    side_effect <= 1'b1;
    return 3;
  endfunction

  localparam int BAD = value();
endmodule
