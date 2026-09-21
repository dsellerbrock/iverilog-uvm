// An ordinary-local winner must cancel the mutation registration before the
// class root is replaced and both old/new objects mutate.
class mw_root_cfg_t; int idx; endclass
module sv_mixed_event_root_after_ordinary;
  mw_root_cfg_t cfg;
  task automatic exercise;
    mw_root_cfg_t old_cfg;
    logic [3:0] sr;
    int wakes;
    cfg = new; cfg.idx = 1; old_cfg = cfg; sr = '0; wakes = 0;
    fork
      begin @(sr[cfg.idx]); wakes++; end
    join_none
    #0 sr[1] = 1;
    #1;
    if (wakes != 1) $fatal(1, "ordinary winner wakes=%0d", wakes);
    cfg = new; cfg.idx = 2;
    old_cfg.idx = 0;
    cfg.idx = 3;
    #1;
    if (wakes != 1 || sr[1] !== 1)
      $fatal(1, "root replacement after ordinary winner wakes=%0d", wakes);
    $display("PASS mixed_root_after_ordinary");
  endtask
  initial exercise();
endmodule
