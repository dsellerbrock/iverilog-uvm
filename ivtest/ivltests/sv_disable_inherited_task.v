// IEEE 1800-2017/2023 9.6.2: disable names a task through ordinary scope
// resolution, which in a class method includes inherited methods.
// Reduced from OpenTitan lc_ctrl_smoke_vseq.sv:34 (disable run_clk_byp_rsp).
class base_seq;
  int base_ticks, override_ticks, other_ticks;
  virtual task run_rsp(); forever begin #1 base_ticks++; end endtask
  task run_other(); forever begin #1 other_ticks++; end endtask
endclass

class derived_seq extends base_seq;
  task start(); fork run_other(); join_none #5; endtask
  task stop(); disable run_other; endtask
endclass

class override_seq extends base_seq;
  virtual task run_rsp(); forever begin #1 override_ticks++; end endtask
  task start(); fork run_rsp(); join_none #5; endtask
  task stop(); disable run_rsp; endtask
endclass

module test;
  derived_seq d;
  override_seq o;
  int snap_other, snap_override;
  bit failed = 0;

  initial begin
    d = new;
    d.start();
    d.stop();
    snap_other = d.other_ticks;
    o = new;
    o.start();
    o.stop();
    snap_override = o.override_ticks;
    #10;
    if (snap_other == 0 || d.other_ticks != snap_other) begin
      $display("FAILED inherited task still running: %0d -> %0d", snap_other, d.other_ticks);
      failed = 1;
    end
    if (snap_override == 0 || o.override_ticks != snap_override || o.base_ticks != 0) begin
      $display("FAILED override: %0d -> %0d base=%0d", snap_override, o.override_ticks, o.base_ticks);
      failed = 1;
    end
    if (!failed) $display("PASSED");
  end
endmodule
