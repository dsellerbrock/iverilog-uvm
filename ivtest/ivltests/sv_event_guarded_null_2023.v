interface guard_if;
  logic wake;
endinterface

class guard_cfg;
  virtual guard_if vif;
endclass

module test;
  guard_if bus();
  guard_cfg cfg;
  logic guard, plain, select;
  int and_hits, or_hits, ternary_hits;

  initial begin
    cfg = new;
    cfg.vif = null;
    guard = 0;
    plain = 0;
    select = 0;
    fork
      begin @(posedge (guard && cfg.vif.wake)); and_hits++; end
      begin @(negedge (1'b1 || cfg.vif.wake)); or_hits++; end
      begin @(posedge (select ? cfg.vif.wake : plain)); ternary_hits++; end
    join_none
    #1;
    plain = 1;
    #1;
    if (and_hits || or_hits || ternary_hits != 1)
      $fatal(1, "guarded null result mismatch %0d %0d %0d",
             and_hits, or_hits, ternary_hits);
    cfg.vif = bus;
    bus.wake = 0;
    #1;
    guard = 1;
    #1;
    bus.wake = 1;
    #1;
    if (and_hits != 1) $fatal(1, "guarded wait did not rearm");
    $display("PASSED guarded null expressions");
  end
endmodule
