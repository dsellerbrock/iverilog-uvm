// Phase 62 / I5: uvm_callbacks#(T,CB)::add() must not warn CBUNREG
// after a successful m_register_pair() — virtual dispatch on the
// parameterized class's m_is_registered/m_is_for_me/m_am_i_a methods
// must reach the override in uvm_callbacks#(T,CB), not the base
// uvm_callbacks_base stub (which returns 0).
//
// Pre-fix: should_eagerly_elaborate_class_method_ in elaborate.cc
// (and should_seed_specialized_method_body_ in elab_scope.cc) skipped
// emitting these virtual override methods for the lazy-elaborated
// uvm_callbacks specialization, so dispatch fell through to base.
`timescale 1ns/1ps
`include "uvm_macros.svh"
import uvm_pkg::*;

class my_cb extends uvm_callback;
  `uvm_object_utils(my_cb)
  function new(string name = "my_cb"); super.new(name); endfunction
endclass

class my_drv extends uvm_component;
  `uvm_component_utils(my_drv)
  `uvm_register_cb(my_drv, my_cb)
  function new(string name = "my_drv", uvm_component parent = null);
    super.new(name, parent);
  endfunction
endclass

module top;
  initial begin
    bit reg_ok;
    my_drv drv;
    my_cb  cb;
    reg_ok = uvm_callbacks#(my_drv,my_cb)::m_register_pair("my_drv","my_cb");
    if (!reg_ok) $fatal(1, "FAIL: m_register_pair returned 0");

    drv = new("drv", null);
    cb = new("cb");
    // The uvm_test harness greps for UVM_WARNING/UVM_FATAL — if a
    // CBUNREG warning fires here, the test fails automatically.
    uvm_callbacks#(my_drv, my_cb)::add(drv, cb);

    $display("PASS: uvm_callbacks#(T,CB)::add() completed without CBUNREG");
    $finish;
  end
endmodule
