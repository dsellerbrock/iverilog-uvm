// One compound event has two mutation paths and one automatic-local source.
class mw_multi_cfg_t; int left; int right; endclass
module sv_mixed_event_multi_path_local;
  mw_multi_cfg_t cfg;
  bit completed;
  task automatic exercise;
    logic [3:0] sr;
    int wakes;
    cfg = new; cfg.left = 0; cfg.right = 2; sr = '0; wakes = 0;
    fork begin #0 sr[2] = 1; end join_none
    @(sr[cfg.left] || sr[cfg.right]);
    wakes++;
    #1;
    if (sr[cfg.left] !== 0 || sr[cfg.right] !== 1 || wakes != 1)
      $fatal(1, "mixed multi path local left=%b right=%b wakes=%0d", sr[cfg.left], sr[cfg.right], wakes);
    completed = 1;
    $display("PASS mixed_multi_path_local");
  endtask
  initial begin completed = 0; exercise(); end
  initial begin
    #5;
    if (!completed) $fatal(1, "mixed multi-path local did not complete");
  end
endmodule
