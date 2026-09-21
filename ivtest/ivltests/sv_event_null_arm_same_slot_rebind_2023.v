interface null_arm_if;
  logic wake;
endinterface
class null_arm_cfg;
  virtual null_arm_if vif;
endclass
module test;
  null_arm_if bus();
  null_arm_cfg cfg;
  event arming;
  initial begin
    cfg = new;
    cfg.vif = null;
    fork begin
      -> arming;
      @(posedge (|cfg.vif.wake));
      $fatal(1, "same-slot rebind rescued an illegal null dereference");
    end join_none
    @arming;
    cfg.vif = bus;
    bus.wake = 1;
    #1;
    $fatal(1, "null-at-arm did not report a runtime error");
  end
endmodule
