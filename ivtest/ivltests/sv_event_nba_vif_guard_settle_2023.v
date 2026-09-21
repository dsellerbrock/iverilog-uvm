interface nba_guard_if;
  logic wake;
endinterface
class nba_guard_cfg;
  virtual nba_guard_if vif;
endclass
module nba_vif_guard_settle;
  nba_guard_if bus0(), bus1();
  nba_guard_cfg first, second;
  logic enable0, enable1;
  logic null0, null1, bind0, bind1;
  int hits0, hits1;
  bit done;
  always @(posedge null0) first.vif = null;
  always @(posedge null1) second.vif = null;
  always @(posedge bind0) first.vif = bus0;
  always @(posedge bind1) second.vif = bus1;
  initial begin
    first = new; second = new;
    first.vif = bus0; second.vif = bus1;
    enable0 = 1; enable1 = 1; bus0.wake = 0; bus1.wake = 0;
    fork
      begin forever begin @(posedge (enable0 && first.vif.wake)); hits0++; end end
      begin forever begin @(posedge (enable1 && second.vif.wake)); hits1++; end end
    join_none
    #1;
    // Both source orders settle to a controlling false before the VIF is null.
    enable0 <= 0; null0 <= 1; bus0.wake <= 1;
    null1 <= 1; bus1.wake <= 1; enable1 <= 0;
    #1;
    if (hits0 || hits1) $fatal(1, "inactive null NBA woke %0d %0d", hits0, hits1);
    // An NBA-triggered Active rebind and enable update must settle to true.
    bind0 <= 1; enable0 <= 1;
    enable1 <= 1; bind1 <= 1;
    #1;
    if (hits0 != 1 || hits1 != 1)
      $fatal(1, "NBA rebind result %0d %0d", hits0, hits1);
    $display("PASSED"); done = 1;
  end
  initial #20 if (!done) $fatal(1, "TIMEOUT");
endmodule
