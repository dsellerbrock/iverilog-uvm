// IEEE 1800-2017/2023 13.4.4: a declaration initializer is not an allowed
// caller for a function that schedules background work.
module sv_function_deferred_fork_context_fail;
  logic target = 0;
  function integer schedule();
    fork
      #1 target = 1;
    join_none
    schedule = 1;
  endfunction
  integer unused = schedule();
  initial begin #2; $display("UNEXPECTED target=%0d", target); $finish; end
endmodule
