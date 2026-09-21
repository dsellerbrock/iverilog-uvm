// Original pwrmgr shape: class selector pulse over a task-local vector.
class original_selector_cfg_t; int idx; endclass
module sv_mixed_event_original_shape_selector_pulse;
  bit candidate_woke, control_woke, done;
  task automatic run_case;
    original_selector_cfg_t cfg;
    logic [1:0] sr;
    int local_idx;
    cfg = new; cfg.idx = 0; local_idx = 0; sr = 2'b10;
    candidate_woke = 0; control_woke = 0;
    fork
      begin @(sr[cfg.idx]); candidate_woke = 1; end
      begin @(sr[local_idx]); control_woke = 1; end
      begin #1; cfg.idx = 1; local_idx = 1; cfg.idx = 0; local_idx = 0; end
    join_none
    #2;
    if (!control_woke) $fatal(1, "ordinary local-index control lost selector pulse");
    if (!candidate_woke) $fatal(1, "original shape lost selector pulse");
  endtask
  initial begin run_case(); done = 1; $display("PASS original_shape_selector_pulse"); end
  initial begin #5; if (!done) $fatal(1, "original shape selector pulse did not complete"); end
endmodule
