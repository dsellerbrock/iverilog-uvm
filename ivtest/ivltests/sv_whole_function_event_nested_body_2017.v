module sv_whole_function_event_nested_body;
  class state_t;
    int idx;
  endclass
  class cfg_t;
    state_t child;
    int selector_calls;
    function automatic int selector(input state_t arg);
      selector_calls++;
      return child.idx + arg.idx;
    endfunction
  endclass

  cfg_t cfg;
  state_t arg;
  logic [1:0] data;
  int nested_wakes, argument_wakes;
  task automatic wait_nested;
    @(data[cfg.selector(arg)]);
    nested_wakes++;
  endtask
  task automatic wait_argument;
    @(data[cfg.selector(arg)]);
    argument_wakes++;
  endtask

  initial begin
    cfg = new; cfg.child = new; arg = new;
    data = '0; data[1] = 1; cfg.child.idx = 0; arg.idx = 0; cfg.selector_calls = 0;
    fork wait_nested(); join_none
    #1;
    if (cfg.selector_calls != 1) $fatal(1, "selector evaluated %0d times while arming nested waiter", cfg.selector_calls);
    cfg.child.idx = 1;
    #0 if (nested_wakes != 1) $fatal(1, "nested method-body property change was missed");

    data = '0; data[1] = 1; cfg.child.idx = 0; arg.idx = 0; cfg.selector_calls = 0;
    fork wait_argument(); join_none
    #1;
    if (cfg.selector_calls != 1) $fatal(1, "selector evaluated %0d times while arming object-argument waiter", cfg.selector_calls);
    arg.idx = 1;
    #0 if (argument_wakes != 1) $fatal(1, "object-argument field change was missed");
    $display("PASS whole-function-nested-body");
    $finish;
  end
endmodule
