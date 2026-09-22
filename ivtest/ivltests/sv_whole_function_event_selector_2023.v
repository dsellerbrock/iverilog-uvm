module sv_whole_function_event_selector;
  class cfg_t;
    int base;
    int selector_calls;
    function automatic int selector(input int offset);
      selector_calls++;
      return base + offset;
    endfunction
  endclass

  cfg_t cfg = new;
  logic [1:0] data;
  int offset;
  int arg_wakes, body_wakes, pulse_wakes;

  task automatic wait_for_arg;
    @(data[cfg.selector(offset)]);
    arg_wakes++;
  endtask
  task automatic wait_for_body;
    @(data[cfg.selector(offset)]);
    body_wakes++;
  endtask
  task automatic wait_for_pulse;
    @(data[cfg.selector(offset)]);
    pulse_wakes++;
  endtask

  initial begin
    // A changed unselected element must not wake. Changing the ordinary argument
    // selects data[1], whose already-different value must wake exactly once.
    data = '0; cfg.base = 0; offset = 0; cfg.selector_calls = 0;
    fork wait_for_arg(); join_none
    #1;
    if (cfg.selector_calls != 1) $fatal(1, "selector evaluated %0d times while arming", cfg.selector_calls);
    data[1] = 1;
    #0 if (arg_wakes != 0) $fatal(1, "unselected change woke waiter");
    offset = 1;
    #0 if (arg_wakes != 1) $fatal(1, "ordinary function argument did not update selection");

    // A member read only inside selector() is a separate sensitivity source.
    data = '0; data[1] = 1; cfg.base = 0; offset = 0; cfg.selector_calls = 0;
    fork wait_for_body(); join_none
    #1;
    if (cfg.selector_calls != 1) $fatal(1, "selector evaluated %0d times while arming body waiter", cfg.selector_calls);
    cfg.base = 1;
    #0 if (body_wakes != 1) $fatal(1, "method-body dependency did not update selection");

    // An event occurrence is retained even when the selected value returns in the same time slot.
    data = '0; cfg.base = 0; offset = 0;
    fork wait_for_pulse(); join_none
    #1;
    data[0] = 1;
    data[0] = 0;
    #0 if (pulse_wakes != 1) $fatal(1, "selected pulse was lost");
    $display("PASS whole-function-selector");
    $finish;
  end
endmodule
