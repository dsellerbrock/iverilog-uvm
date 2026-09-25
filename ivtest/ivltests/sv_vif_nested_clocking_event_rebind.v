`timescale 1ns/1ps

interface nested_clocking_child_if(input logic clk);
  logic valid = 0;
  logic ready = 0;
  clocking mon_cb @(posedge clk);
    input valid, ready;
  endclocking
endinterface

interface nested_clocking_parent_if(input logic clk);
  nested_clocking_child_if child(clk);
  clocking parent_cb @(posedge clk);
    input clk;
  endclocking
endinterface

class nested_clocking_cfg;
  virtual nested_clocking_parent_if vif;
endclass

class nested_clocking_monitor;
  nested_clocking_cfg cfg;
  int wakes;
  time wake_time[2];
  bit sampled_valid;
  bit sampled_ready;
  bit handshake;

  function new(nested_clocking_cfg c);
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

class nested_clocking_direct_child;
  virtual nested_clocking_child_if vif;
  int wakes;
  bit handshake;

  task watch();
    @(vif.mon_cb);
    wakes++;
    handshake = vif.mon_cb.valid && vif.mon_cb.ready;
  endtask
endclass

class nested_clocking_direct_parent;
  virtual nested_clocking_parent_if vif;
  int wakes;

  task watch();
    @(vif.parent_cb);
    wakes++;
  endtask
endclass

module sv_vif_nested_clocking_event_rebind;
  logic clk0 = 0, clk1 = 0;
  always #5 clk0 = !clk0;
  always #7 clk1 = !clk1;
  nested_clocking_parent_if p0(clk0), p1(clk1);
  nested_clocking_cfg cfg;
  nested_clocking_monitor mon;
  nested_clocking_direct_child direct_child;
  nested_clocking_direct_parent direct_parent;

  initial begin
    cfg = new;
    cfg.vif = p0;
    mon = new(cfg);
    direct_child = new;
    direct_child.vif = p0.child;
    direct_parent = new;
    direct_parent.vif = p0;

    fork
      mon.watch_child();
      direct_child.watch();
      direct_parent.watch();
    join_none

    #1;
    p0.child.valid = 1;
    p0.child.ready = 1;
    #5;
    if (mon.wakes != 1 || mon.wake_time[0] != 5 ||
        !mon.sampled_valid || !mon.sampled_ready || !mon.handshake)
      $fatal(1, "p0 nested event/sample mismatch");
    if (direct_child.wakes != 1 || !direct_child.handshake || direct_parent.wakes != 1)
      $fatal(1, "direct clocking controls failed");

    #2;
    cfg.vif = p1;
    fork mon.watch_child(); join_none
    #1;
    p0.child.valid = 0;
    p0.child.ready = 0;
    #7;
    if (mon.wakes != 1)
      $fatal(1, "nested wait woke before selected p1 edge");

    p1.child.valid = 1;
    p1.child.ready = 0;
    #6;
    if (mon.wakes != 2 || mon.wake_time[1] != 21 ||
        !mon.sampled_valid || mon.sampled_ready || mon.handshake)
      $fatal(1, "p1 nested event/sample mismatch");

    $display("PASSED");
    $finish;
  end
endmodule
