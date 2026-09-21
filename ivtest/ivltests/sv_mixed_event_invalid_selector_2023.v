class cfg_t; logic [1:0] idx; endclass
module sv_mixed_event_invalid_selector;
  cfg_t cfg;
  task automatic exercise;
    logic [3:0] sr; int wakes;
    sr = '0; wakes = 0; cfg.idx = 'x;
    fork
      begin @(sr[cfg.idx]); wakes++; end
      begin
        #1 sr[0] = 1; // index remains X, expression remains X
        #1 if (wakes != 0 || sr[cfg.idx] !== 1'bx) $fatal(1, "invalid selector false wake=%0d selected=%b", wakes, sr[cfg.idx]);
        cfg.idx = 1; // selected expression X -> 0
        #1 if (wakes != 1 || sr[cfg.idx] !== 1'b0) $fatal(1, "valid selector transition woke=%0d selected=%b", wakes, sr[cfg.idx]);
      end
    join
  endtask
  initial begin cfg = new; exercise(); $display("PASS invalid_selector"); end
endmodule
