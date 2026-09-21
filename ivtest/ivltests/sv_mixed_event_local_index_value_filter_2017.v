// A local selector is an ordinary dependency of a syntactically direct
// cfg.bits[idx] select: a same-value selector change must rearm, while a
// different selected value must release the original one-shot event control.
class mw_index_cfg_t; logic [3:0] bits; endclass
module sv_mixed_event_local_index_value_filter;
  bit completed;
  task automatic same_value_then_value_change;
    mw_index_cfg_t cfg;
    int idx, wakes;
    cfg = new; cfg.bits = '0; idx = 0; wakes = 0;
    fork
      begin
        #0 idx = 1; // bits[0] and bits[1] remain 0: must not wake.
        #0 if (wakes != 0) $fatal(1, "same-value selector woke=%0d", wakes);
        cfg.bits[1] = 1;
      end
    join_none
    @(cfg.bits[idx]);
    wakes++;
    #1;
    if (idx != 1 || cfg.bits[idx] !== 1 || wakes != 1)
      $fatal(1, "same/value filter idx=%0d bit=%b wakes=%0d", idx, cfg.bits[idx], wakes);
  endtask

  task automatic different_value_selector;
    mw_index_cfg_t cfg;
    int idx, wakes;
    cfg = new; cfg.bits = '0; cfg.bits[1] = 1; idx = 0; wakes = 0;
    fork begin #0 idx = 1; end join_none
    @(cfg.bits[idx]);
    wakes++;
    #1;
    if (idx != 1 || cfg.bits[idx] !== 1 || wakes != 1)
      $fatal(1, "different selector idx=%0d bit=%b wakes=%0d", idx, cfg.bits[idx], wakes);
  endtask

  initial begin
    same_value_then_value_change();
    different_value_selector();
    completed = 1;
    $display("PASS mixed_local_index_value_filter");
  end
  initial begin
    completed = 0;
    #5;
    if (!completed) $fatal(1, "mixed local-index value filter did not complete");
  end
endmodule
