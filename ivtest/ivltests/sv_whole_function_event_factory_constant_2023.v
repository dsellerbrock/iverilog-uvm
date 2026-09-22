module sv_whole_function_event_factory_constant;
  class leaf_t;
    function automatic logic constant_value(); return 1'b0; endfunction
  endclass
  class cfg_t;
    int factory_calls;
    function automatic leaf_t receiver();
      leaf_t made;
      factory_calls++;
      made = new;
      return made;
    endfunction
  endclass
  cfg_t cfg;
  bit woke;
  task automatic waiter;
    @(cfg.receiver().constant_value());
    woke = 1;
  endtask
  initial begin
    cfg = new; woke = 0;
    fork waiter(); join_none
    #1 if (cfg.factory_calls != 1) $fatal(1, "factory evaluated %0d times while arming", cfg.factory_calls);
    #2 if (woke) $fatal(1, "constant factory receiver woke spontaneously");
    $display("PASS whole-function-factory-constant");
    $finish;
  end
endmodule
