// A program/Reactive one-shot mixed wait. The writer is queued before the
// parent blocks; the original parent must nevertheless arm sr[cfg.idx] first.
class mw_cfg_t; int idx; endclass
module sv_mixed_event_program_queued_writer;
  program automatic reactive_test;
    mw_cfg_t cfg;
    bit completed;
    task automatic exercise;
      logic [3:0] sr;
      int wakes;
      cfg = new; cfg.idx = 1; sr = '0; wakes = 0;
      fork begin sr[1] = 1; end join_none
      @(sr[cfg.idx]);
      wakes++;
      #1;
      if (sr[cfg.idx] !== 1 || wakes != 1)
        $fatal(1, "mixed Reactive queued writer selected=%b wakes=%0d", sr[cfg.idx], wakes);
      completed = 1;
      $display("PASS mixed_program_queued_writer");
    endtask
    initial begin completed = 0; exercise(); end
    initial begin
      #5;
      if (!completed) $fatal(1, "mixed Reactive queued writer did not complete");
    end
  endprogram
endmodule
