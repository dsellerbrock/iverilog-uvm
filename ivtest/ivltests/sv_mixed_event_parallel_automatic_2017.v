// Two automatic activations must retain separate local-vector and selector state.
class mw_parallel_cfg_t; int idx; endclass
module sv_mixed_event_parallel_automatic;
  int completed;
  task automatic exercise(input int slot);
    mw_parallel_cfg_t cfg;
    logic [3:0] sr;
    int wakes;
    cfg = new; cfg.idx = slot; sr = '0; wakes = 0;
    fork begin #0 sr[slot] = 1; end join_none
    @(sr[cfg.idx]);
    wakes++;
    #1;
    if (sr[cfg.idx] !== 1 || wakes != 1)
      $fatal(1, "mixed automatic slot=%0d selected=%b wakes=%0d", slot, sr[cfg.idx], wakes);
    completed++;
  endtask
  initial begin
    completed = 0;
    fork exercise(0); exercise(3); join
    if (completed != 2) $fatal(1, "parallel automatic completed=%0d", completed);
    $display("PASS mixed_parallel_automatic");
  end
  initial begin
    #5;
    if (completed != 2) $fatal(1, "parallel automatic did not complete=%0d", completed);
  end
endmodule
