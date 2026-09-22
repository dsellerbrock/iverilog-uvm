module sv_whole_function_event_receiver_rebind;
  class cfg_t;
    int idx;
    int selector_calls;
    function automatic int selector();
      selector_calls++;
      return idx;
    endfunction
  endclass

  cfg_t cfg, replacement;
  logic [1:0] data;
  int wakes;
  task automatic waiter;
    @(data[cfg.selector()]);
    wakes++;
  endtask

  initial begin
    cfg = new; replacement = new;
    cfg.idx = 0; replacement.idx = 1; data = '0;
    fork waiter(); join_none
    #1;
    if (cfg.selector_calls != 1) $fatal(1, "receiver selector evaluated %0d times while arming", cfg.selector_calls);
    cfg = replacement;
    #0 if (wakes != 0) $fatal(1, "equal-value receiver rebind woke waiter");
    data[1] = 1;
    #0 if (wakes != 1) $fatal(1, "post-rebind selected mutation was missed");
    $display("PASS whole-function-receiver-rebind");
    $finish;
  end
endmodule
