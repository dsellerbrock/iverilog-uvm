module core_four_state_widths;
  class cfg_t;
    logic [2:0] narrow;
    logic [8:0] wide;
  endclass
  class state_t;
    cfg_t cfg;
    int wakes;
    function new; cfg = new; endfunction
    task automatic wait_one;
      @(cfg.narrow, cfg.wide);
      wakes++;
    endtask
  endclass
  state_t s;
  task automatic arm_and_set_narrow(input logic [2:0] value, input bit expect_wake);
    int prior_wakes;
    prior_wakes = s.wakes;
    fork s.wait_one(); join_none
    #1 s.cfg.narrow = value;
    #1 if ((s.wakes != prior_wakes) != expect_wake)
      $fatal(1, "narrow transition mismatch value=%b before=%0d after=%0d", value, prior_wakes, s.wakes);
  endtask
  initial begin
    s = new; s.cfg.narrow = 3'b000; s.cfg.wide = 9'h000;
    arm_and_set_narrow(3'b000, 0);
    s.cfg.narrow = 3'b0x0;
    #1 if (s.wakes != 1) $fatal(1, "0-to-X missed");
    arm_and_set_narrow(3'b0z0, 1);
    fork s.wait_one(); join_none
    #1 s.cfg.wide = 9'b1x0z10101;
    #1 if (s.wakes != 3) $fatal(1, "mixed-width wide transition missed");
    fork s.wait_one(); join_none
    #1 s.cfg.wide = 9'b1x0z10101;
    #1 if (s.wakes != 3) $fatal(1, "four-state equal assignment woke");
    disable fork;
    $display("PASS core four state widths");
    $finish;
  end
endmodule
