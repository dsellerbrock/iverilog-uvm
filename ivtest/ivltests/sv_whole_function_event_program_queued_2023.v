class whole_program_cfg_t;
  int idx;
  function automatic int selector(); return idx; endfunction
endclass
module sv_whole_function_event_program_queued;
  program automatic reactive_test;
    whole_program_cfg_t cfg;
    logic [1:0] data;
    bit completed;
    task automatic exercise;
      int wakes;
      cfg = new; cfg.idx = 1; data = '0; wakes = 0;
      fork begin data[1] = 1; end join_none
      @(data[cfg.selector()]);
      wakes++;
      #1;
      if (data[cfg.selector()] !== 1 || wakes != 1)
        $fatal(1, "whole function Reactive queued writer selected=%b wakes=%0d", data[cfg.selector()], wakes);
      completed = 1;
      $display("PASS whole-function-program-queued");
    endtask
    initial begin completed = 0; exercise(); end
    initial begin #5; if (!completed) $fatal(1, "whole function Reactive queued writer did not complete"); end
  endprogram
endmodule
