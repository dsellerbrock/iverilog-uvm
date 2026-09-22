module sv_whole_function_event_assoc_num;
  class cfg_t;
    int values[string];
    function automatic int num_value(); return values.num(); endfunction
  endclass
  cfg_t cfg;
  int wakes;
  task automatic waiter; @(cfg.num_value()); wakes++; endtask
  initial begin
    cfg = new; wakes = 0;
    fork waiter(); join_none
    #1; cfg.values["first"] = 7;
    #0 if (wakes != 1) $fatal(1, "associative-array num method event did not wake");
    $display("PASS whole-function-assoc-num");
    $finish;
  end
endmodule
