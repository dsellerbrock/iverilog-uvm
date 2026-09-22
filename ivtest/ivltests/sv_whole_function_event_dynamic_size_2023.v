module sv_whole_function_event_dynamic_size;
  class cfg_t;
    int values[];
    function automatic int size_value(); return values.size(); endfunction
  endclass
  cfg_t cfg;
  int wakes;
  task automatic waiter; @(cfg.size_value()); wakes++; endtask
  initial begin
    cfg = new; cfg.values = new[0]; wakes = 0;
    fork waiter(); join_none
    #1; cfg.values = new[2];
    #0 if (wakes != 1) $fatal(1, "dynamic-array size method event did not wake");
    $display("PASS whole-function-dynamic-size");
    $finish;
  end
endmodule
