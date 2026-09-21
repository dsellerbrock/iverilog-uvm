module top;
  class cfg_t;
    logic [1:0] bits; int idx; int calls;
    function automatic int selector(); calls++; return idx; endfunction
  endclass
  cfg_t cfg = new;
  int wakes;
  task automatic waiter;
    @(cfg.bits[cfg.selector()]); wakes++;
  endtask
  initial begin
    cfg.bits = 0; cfg.idx = 0; cfg.calls = 0;
    fork waiter(); join_none
    #1 begin
      cfg.idx = 1; // method dependency changes the selected element
      cfg.bits[1] = 1;
    end
    #1 begin
      if (wakes != 1) $fatal(1, "method selector dependency missed: %0d", wakes);
      if (cfg.calls < 1) $fatal(1, "selector never evaluated");
      $display("PASS method-selector-dependency"); $finish(0);
    end
  end
endmodule
