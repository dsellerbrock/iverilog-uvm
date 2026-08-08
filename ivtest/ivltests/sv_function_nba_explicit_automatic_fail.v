// A declaration-level automatic override remains automatic even inside a
// default-static function. It cannot be an NBA target or be referenced by an
// intra-assignment count/event control that outlives the function call.
module sv_function_nba_explicit_automatic_fail;
  logic side_effect;
  event wake;

  function void bad();
    automatic logic local_value;
    local_value <= 1'b1;
  endfunction

  function void bad_count();
    automatic int repetitions;
    side_effect <= repeat (repetitions) @(wake) 1'b1;
  endfunction

  function void bad_event();
    automatic logic trigger;
    side_effect <= @(posedge trigger) 1'b1;
  endfunction

  initial begin
    bad();
    bad_count();
    bad_event();
  end
endmodule
