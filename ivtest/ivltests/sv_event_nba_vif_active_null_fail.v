interface nba_active_null_if;
  logic wake;
endinterface
class nba_active_null_cfg;
  virtual nba_active_null_if vif;
endclass
module nba_vif_active_null_fail;
  nba_active_null_if bus();
  nba_active_null_cfg cfg;
  logic enable, make_null;
  always @(posedge make_null) cfg.vif = null;
  initial begin
    cfg = new; cfg.vif = bus; enable = 1; bus.wake = 0;
    fork begin @(posedge (enable && cfg.vif.wake)); $fatal(1, "null event woke"); end join_none
    #1 make_null <= 1;
    #2 $fatal(1, "active null event was accepted");
  end
endmodule
