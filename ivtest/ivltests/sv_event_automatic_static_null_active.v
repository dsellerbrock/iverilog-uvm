interface automatic_static_null_if;
  logic wake;
endinterface

class automatic_static_null_cfg;
  virtual automatic_static_null_if vif;
endclass

module test;
  automatic_static_null_if bus();
  automatic_static_null_cfg cfg;
  event starting;

  task automatic watch;
    ->starting;
    @(posedge (|cfg.vif.wake));
    $fatal(1, "active automatic waiter resumed after null rebind");
  endtask

  initial begin
    cfg = new;
    cfg.vif = bus;
    bus.wake = 0;
    #1;
    fork watch(); join_none
    @starting;
    #1;
    cfg.vif = null;
    #1;
    $fatal(1, "active automatic null dereference was not fatal");
  end
endmodule
