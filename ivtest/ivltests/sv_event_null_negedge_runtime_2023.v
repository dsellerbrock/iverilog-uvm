interface null_neg_if;
  logic wake;
endinterface
class null_neg_cfg;
  virtual null_neg_if vif;
endclass
module test;
  null_neg_if bus();
  null_neg_cfg cfg;
  initial begin
    cfg = new;
    cfg.vif = bus;
    bus.wake = 1;
    #1;
    fork begin
      @(negedge (|cfg.vif.wake));
      $fatal(1, "null negedge resumed the waiting body");
    end join_none
    #1;
    cfg.vif = null;
    #1;
    $fatal(1, "armed null negedge was not fatal");
  end
endmodule
