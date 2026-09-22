module core_comma_or;
  class cfg_t;
    logic on;
  endclass
  class driver_t;
    cfg_t cfg;
    logic [3:0] pulses;
    int wakes;
    function new; cfg = new; endfunction
    task automatic wait_comma;
      @(cfg.on, pulses);
      wakes++;
    endtask
    task automatic wait_or;
      @(cfg.on or pulses);
      wakes++;
    endtask
  endclass
  driver_t d;
  initial begin
    d = new;
    fork d.wait_comma(); join_none
    #1 d.cfg.on = 1'b1;
    #1 if (d.wakes != 1) $fatal(1, "comma first leaf missed");
    fork d.wait_comma(); join_none
    #1 d.pulses = 4'ha;
    #1 if (d.wakes != 2) $fatal(1, "comma second leaf missed");
    fork d.wait_or(); join_none
    #1 d.cfg.on = 1'b0;
    #1 if (d.wakes != 3) $fatal(1, "or first leaf missed");
    fork d.wait_or(); join_none
    #1 d.pulses = 4'h5;
    #1 if (d.wakes != 4) $fatal(1, "or second leaf missed");
    $display("PASS core comma or");
    $finish;
  end
endmodule
