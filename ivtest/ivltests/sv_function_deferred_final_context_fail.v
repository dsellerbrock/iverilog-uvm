// IEEE 1800-2017/2023 9.2.3 and 13.4.4: final is not an initial/always/fork
// caller, so a function may not schedule background work there.
module sv_function_deferred_final_context_fail;
  logic target = 0;
  function integer schedule();
    fork
      #1 target = 1;
    join_none
    schedule = 1;
  endfunction
  integer result;
  final result = schedule();
  initial #1;
endmodule
