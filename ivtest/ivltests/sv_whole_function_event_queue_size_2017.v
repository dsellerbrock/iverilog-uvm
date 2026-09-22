module sv_whole_function_event_queue_size;
  class cfg_t;
    int q[$];
    function automatic int queue_size(); return q.size(); endfunction
  endclass
  cfg_t cfg;
  int wakes;
  task automatic waiter; @(cfg.queue_size()); wakes++; endtask
  initial begin
    cfg = new; wakes = 0;
    fork waiter(); join_none
    #1;
    cfg.q.push_back(7);
    #0 if (wakes != 1) $fatal(1, "queue-size method event did not wake");
    $display("PASS whole-function-queue-size");
    $finish;
  end
endmodule
