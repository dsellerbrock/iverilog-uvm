module core_rebind_refresh;
  class cfg_t;
    logic on;
    logic sibling;
    function new; on = 0; sibling = 0; endfunction
  endclass
  class driver_t;
    cfg_t cfg;
    logic pulses;
    int wakes;
    task automatic wait_one;
      @(cfg.on, pulses);
      wakes++;
    endtask
  endclass
  driver_t d;
  cfg_t old_cfg, new_cfg;
  initial begin
    d = new; old_cfg = new; new_cfg = new; d.cfg = old_cfg;
    fork d.wait_one(); join_none
    #1 begin
      d.cfg = new_cfg;       // selected value remains zero; refresh owner now
      new_cfg.on = 1'b1;     // must be observed in this same active execution
    end
    #1 if (d.wakes != 1) $fatal(1, "equal rebind did not refresh before mutation");
    fork d.wait_one(); join_none
    #1;
    old_cfg.on = 1'b1;
    new_cfg.sibling = 1'b1;
    #1 if (d.wakes != 1) $fatal(1, "old or unselected member caused wake");
    d.pulses = 1'b1;
    #1 if (d.wakes != 2) $fatal(1, "second listed leaf missed after rebind");
    $display("PASS core rebind refresh");
    $finish;
  end
endmodule
