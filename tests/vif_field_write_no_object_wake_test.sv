// Regression: a virtual-interface FIELD write must NOT spuriously wake an
// @(obj.member) / wait(obj.member) anyedge waiter on the vif's containing
// object.
//
// `cfg.vif.field <= v` drives an interface SIGNAL -- already delivered to the
// design by set_vec4, and observed by @(vif.field) waiters through the edge
// functor.  It must NOT fire the object-anyedge machinery (notify_mutated_
// object_root_) that wakes wait(cfg.other_member): a vif field write changes a
// wire, not an object-member handle.
//
// Previously every vif field write propagated the vif object up to the cfg
// root and fired ALL @(cfg.member) waiters.  In OpenTitan aon_timer DV this let
// the UVM tl_host_driver threads (d_ready_rsp / a_channel_thread /
// d_channel_thread), which each sit in a DV_SPINWAIT wait(cfg.in_reset), drive
// each other in an unbounded zero-time cross-fire every time they toggled a TL
// bus signal -- the smoke vseq hung (frozen sim time, 100% CPU) at 303us.
//
// The complement (a real cross-handle write of an OBJECT member DOES wake the
// wait) is covered by wait_member_cross_handle_test.sv and must keep working:
// the discriminator is whether the directly-mutated object is a vif.

interface simple_if;
  logic [3:0] data;
endinterface

module top;

  simple_if intf();

  class cfg_c;
    virtual simple_if vif;
    bit in_reset = 1;     // an object member -- never written below
  endclass

  cfg_c cfg;
  int   spurious = 0;

  initial begin
    cfg = new();
    cfg.vif = intf;
    intf.data = 4'h0;

    // Waiter on an OBJECT member of cfg.  It must only wake if cfg.in_reset
    // actually changes -- never on a vif FIELD write.
    fork
      forever begin
        @(cfg.in_reset);
        spurious++;
      end
    join_none

    #1;
    // Toggle the vif FIELD many times; cfg.in_reset is never touched.
    repeat (10) begin
      cfg.vif.data <= cfg.vif.data + 4'h1;
      #1;
    end
    #1;

    if (spurious == 0)
      $display("PASSED");
    else
      $display("FAILED: vif field write spuriously woke @(cfg.in_reset) %0d times", spurious);
    $finish;
  end

endmodule
