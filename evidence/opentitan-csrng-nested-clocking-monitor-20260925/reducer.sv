interface child_if(input logic clk);
  logic valid = 0;
  logic ready = 0;
  clocking mon_cb @(posedge clk);
    input valid, ready;
  endclocking
endinterface

interface parent_if(input logic clk);
  child_if child(clk);
  clocking parent_cb @(posedge clk);
    input clk;
  endclocking
endinterface

class cfg_t;
  virtual parent_if vif;
endclass

class monitor_t;
  cfg_t cfg;
  int wakes;
  time wake_time[3];
  bit handshake;
  bit sampled_valid;
  bit sampled_ready;

  function new(cfg_t c);
    cfg = c;
  endfunction

  task watch_child();
    @(cfg.vif.child.mon_cb);
    wake_time[wakes] = $time;
    wakes++;
    sampled_valid = cfg.vif.child.mon_cb.valid;
    sampled_ready = cfg.vif.child.mon_cb.ready;
    handshake = cfg.vif.child.mon_cb.valid && cfg.vif.child.mon_cb.ready;
  endtask
endclass

class direct_child_t;
  virtual child_if vif;
  int wakes;
  bit handshake;

  task watch();
    @(vif.mon_cb);
    wakes++;
    handshake = vif.mon_cb.valid && vif.mon_cb.ready;
  endtask
endclass

class direct_parent_t;
  virtual parent_if vif;
  int wakes;

  task watch();
    @(vif.parent_cb);
    wakes++;
  endtask
endclass

module tb;
  logic clk0 = 0, clk1 = 0;
  always #5 clk0 = !clk0;
  always #7 clk1 = !clk1;
  parent_if p0(clk0), p1(clk1);
  cfg_t cfg;
  monitor_t mon;
  direct_child_t dc;
  direct_parent_t dp;
  int failures = 0;

  initial begin
    cfg = new;
    cfg.vif = p0;
    mon = new(cfg);
    dc = new;
    dc.vif = p0.child;
    dp = new;
    dp.vif = p0;

    fork
      mon.watch_child();
      dc.watch();
      dp.watch();
    join_none

    #1;
    p0.child.valid = 1;
    p0.child.ready = 1;
    #5;
    $display("CONTROL direct_child=%0d/%b direct_parent=%0d", dc.wakes, dc.handshake, dp.wakes);
    if (dc.wakes != 1 || !dc.handshake || dp.wakes != 1) begin
      failures++;
      $display("FAIL direct control mismatch: child=%0d/%b parent=%0d", dc.wakes, dc.handshake, dp.wakes);
    end
    if (mon.wakes != 1 || mon.wake_time[0] != 5 || !mon.sampled_valid || !mon.sampled_ready || !mon.handshake) begin
      failures++;
      $display("RED p0 nested sample/wake mismatch: wakes=%0d at=%0t sample=%b%b%b", mon.wakes,
               mon.wake_time[0], mon.sampled_valid, mon.sampled_ready, mon.handshake);
    end else $display("PASS p0 nested sample/wake");

    #2;
    cfg.vif = p1;
    fork mon.watch_child(); join_none
    #1;
    p0.child.valid = 0;
    p0.child.ready = 0;
    #7;
    if (mon.wakes != 1) begin
      failures++;
      $display("RED rebound wait woke before selected p1 edge: wakes=%0d at=%0t,%0t", mon.wakes,
               mon.wake_time[0], mon.wake_time[1]);
    end else $display("PASS no premature wake before selected p1 edge");

    p1.child.valid = 1;
    p1.child.ready = 0;
    #6;
    if (mon.wakes != 2 || mon.wake_time[1] != 21 || !mon.sampled_valid || mon.sampled_ready || mon.handshake) begin
      failures++;
      $display("RED p1 nested sample/wake mismatch: wakes=%0d at=%0t,%0t,%0t sample=%b%b%b", mon.wakes,
               mon.wake_time[0], mon.wake_time[1], mon.wake_time[2],
               mon.sampled_valid, mon.sampled_ready, mon.handshake);
    end else $display("PASS p1 nested sample/wake");
    if (failures != 0) $fatal(1, "nested clocking monitor reducer failures=%0d", failures);
    $display("PASS nested clocking event, rebinding, and sampled handshake");
    $finish;
  end
endmodule
