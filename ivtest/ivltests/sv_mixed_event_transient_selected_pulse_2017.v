// IEEE 1800-2017/2023 9.4.2: each selected-expression value transition is an
// event. A same-timeslot 0->1->0 pulse must release both waits even though the
// final snapshot equals the armed snapshot.
class pulse_cfg_t; logic [1:0] bits; endclass
module sv_mixed_event_transient_selected_pulse;
  bit candidate_woke, control_woke, done;
  task automatic run_case;
    pulse_cfg_t cfg;
    logic [1:0] sr;
    int idx;
    cfg = new; cfg.bits = '0; sr = '0; idx = 1;
    candidate_woke = 0; control_woke = 0;
    fork
      begin @(cfg.bits[idx]); candidate_woke = 1; end
      begin @(sr[idx]);       control_woke = 1; end
      begin
        #1;
        cfg.bits[1] = 1; cfg.bits[1] = 0;
        sr[1] = 1;       sr[1] = 0;
      end
    join_none
    #2;
    if (!control_woke) $fatal(1, "ordinary local-index control lost transient pulse");
    if (!candidate_woke) $fatal(1, "candidate lost selected transient pulse");
  endtask
  initial begin run_case(); done = 1; $display("PASS transient_selected_pulse"); end
  initial begin #5; if (!done) $fatal(1, "transient pulse test did not complete"); end
endmodule
