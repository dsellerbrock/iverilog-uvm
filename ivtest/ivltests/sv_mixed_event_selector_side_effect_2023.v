// Diagnostic witness: records whether arm-time observer and descriptor evaluation invoke selector() separately.
module top;
  class cfg_t;
    logic [1:0] bits;
    int idx;
    int selector_calls;
    function automatic int selector();
      selector_calls++;
      return idx;
    endfunction
  endclass
  cfg_t cfg = new;
  bit woke;
  task automatic waiter;
    @(cfg.bits[cfg.selector()]);
    woke = 1;
  endtask
  initial begin
    cfg.bits = 2'b00; cfg.idx = 0; cfg.selector_calls = 0;
    fork waiter(); join_none
    #1 begin
      if (cfg.selector_calls != 1) $fatal(1, "selector evaluated %0d times while arming (capture candidate requires one)", cfg.selector_calls);
      cfg.bits[0] = 1;
    end
    #1 begin
      if (!woke) $fatal(1, "selected mutation was missed");
      $display("PASS selector-side-effect");
      $finish(0);
    end
  end
endmodule
