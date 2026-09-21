// IEEE 1800-2017/2023 9.4.2: selection 0->1->0 changes the expression value
// here (bits[0]=0, bits[1]=1) and must release the one-shot event control.
class selector_cfg_t; logic [1:0] bits; endclass
module sv_mixed_event_transient_selector_pulse;
  bit candidate_woke, control_woke, done;
  task automatic run_case;
    selector_cfg_t cfg;
    logic [1:0] sr;
    int idx;
    cfg = new; cfg.bits = 2'b10; sr = 2'b10; idx = 0;
    candidate_woke = 0; control_woke = 0;
    fork
      begin @(cfg.bits[idx]); candidate_woke = 1; end
      begin @(sr[idx]);       control_woke = 1; end
      begin #1; idx = 1; idx = 0; end
    join_none
    #2;
    if (!control_woke) $fatal(1, "ordinary local-index control lost selector pulse");
    if (!candidate_woke) $fatal(1, "candidate lost selected selector pulse");
  endtask
  initial begin run_case(); done = 1; $display("PASS transient_selector_pulse"); end
  initial begin #5; if (!done) $fatal(1, "transient selector test did not complete"); end
endmodule
