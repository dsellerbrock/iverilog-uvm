// IEEE 1800-2017/2023 13.4.4: this continuous-assignment caller is not an
// initial/always/fork process, so the deferred update must be rejected.
module sv_function_deferred_nba_context_fail;
  logic target = 0;
  function integer schedule();
    target <= 1;
    schedule = 1;
  endfunction
  wire unused = schedule();
  initial begin #1; $display("UNEXPECTED target=%0d", target); $finish; end
endmodule
