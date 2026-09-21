interface null_if;
  logic wake;
endinterface

class null_cfg;
  virtual null_if vif;
endclass

module test;
  null_if bus();
  null_cfg cfg;

  initial begin
    cfg = new;
    cfg.vif = bus;
    bus.wake = 0;
    fork begin
      @(posedge (|cfg.vif.wake));
      $fatal(1, "null virtual-interface dereference resumed the waiter");
    end join_none
    #1;
    cfg.vif = null;
    #1;
    $fatal(1, "armed null virtual-interface dereference was not fatal");
  end
endmodule
