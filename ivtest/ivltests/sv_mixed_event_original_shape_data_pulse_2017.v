// Original pwrmgr shape: task-local vector selected by a class property.
class original_data_cfg_t; int idx; endclass
module sv_mixed_event_original_shape_data_pulse;
  bit candidate_woke, control_woke, done;
  task automatic run_case;
    original_data_cfg_t cfg;
    logic [1:0] sr;
    int local_idx;
    cfg = new; cfg.idx = 1; local_idx = 1; sr = '0;
    candidate_woke = 0; control_woke = 0;
    fork
      begin @(sr[cfg.idx]); candidate_woke = 1; end
      begin @(sr[local_idx]); control_woke = 1; end
      begin #1; sr[1] = 1; sr[1] = 0; end
    join_none
    #2;
    if (!control_woke) $fatal(1, "ordinary local-index control lost data pulse");
    if (!candidate_woke) $fatal(1, "original shape lost data pulse");
  endtask
  initial begin run_case(); done = 1; $display("PASS original_shape_data_pulse"); end
  initial begin #5; if (!done) $fatal(1, "original shape data pulse did not complete"); end
endmodule
