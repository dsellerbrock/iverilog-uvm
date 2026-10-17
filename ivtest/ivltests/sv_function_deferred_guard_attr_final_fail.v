// The compiler's internal function-context marker is reserved from source.
module sv_function_deferred_guard_attr_final_fail;
  logic target = 0;
  function integer schedule();
    target <= 1'b1;
    schedule = 1;
  endfunction
  (* _ivl_function_background_ok = 1 *)
  final begin
    target = schedule();
  end
  initial #1;
endmodule
