class cfg_t; int idx; endclass
module sv_mixed_event_disable_reuse;
  cfg_t cfg;
  task automatic exercise;
    logic [3:0] sr; int stale_wakes, live_wakes;
    sr = '0; cfg.idx = 1; stale_wakes = 0; live_wakes = 0;
    fork : first_wait
      begin @(sr[cfg.idx]); stale_wakes++; end
    join_none
    #1 disable first_wait;
    sr[1] = 1;
    #1 if (stale_wakes != 0) $fatal(1, "disabled waiter woke=%0d", stale_wakes);
    sr[1] = 0;
    fork : second_wait
      begin @(sr[cfg.idx]); live_wakes++; end
    join_none
    #1 sr[1] = 1;
    #1 if (live_wakes != 1 || stale_wakes != 0 || sr[cfg.idx] !== 1'b1)
         $fatal(1, "reuse live=%0d stale=%0d selected=%b", live_wakes, stale_wakes, sr[cfg.idx]);
  endtask
  initial begin cfg = new; exercise(); $display("PASS disable_reuse"); end
endmodule
