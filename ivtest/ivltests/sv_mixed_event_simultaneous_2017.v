class cfg_t; int idx; endclass
module sv_mixed_event_simultaneous;
  cfg_t cfg;
  task automatic exercise;
    logic [3:0] sr; int wakes;
    sr = '0; wakes = 0; cfg.idx = 0;
    fork
      begin @(sr[cfg.idx]); wakes++; end
      begin
        #1 begin cfg.idx = 1; sr[1] = 1; end // final selected expression 0 -> 1
        #1 if (wakes != 1 || sr[cfg.idx] !== 1'b1) $fatal(1, "simultaneous changes woke=%0d selected=%b", wakes, sr[cfg.idx]);
      end
    join
  endtask
  initial begin cfg = new; exercise(); $display("PASS simultaneous"); end
endmodule
