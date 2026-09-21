class cfg_t; int idx; endclass
module sv_mixed_event_selected_unselected;
  cfg_t cfg;
  task automatic exercise;
    logic [3:0] sr; int wakes;
    sr = '0; wakes = 0; cfg.idx = 1;
    fork
      begin @(sr[cfg.idx]); wakes++; end
      begin
        #1 sr[0] = 1; // unselected: sr[cfg.idx] remains 0
        #1 if (wakes != 0 || sr[cfg.idx] !== 1'b0) $fatal(1, "unselected change woke=%0d selected=%b", wakes, sr[cfg.idx]);
        sr[1] = 1; // selected: 0 -> 1
        #1 if (wakes != 1 || sr[cfg.idx] !== 1'b1) $fatal(1, "selected change woke=%0d selected=%b", wakes, sr[cfg.idx]);
      end
    join
  endtask
  initial begin cfg = new; exercise(); $display("PASS selected_unselected"); end
endmodule
