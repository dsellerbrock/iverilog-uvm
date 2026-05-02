// Phase 63b / B4: silence "Enable of unknown task `rgtry.initialize`"
// emitted by UVM uvm_registry.svh:656 in __deferred_init.
//
// The factory registry's initialize() method exists on Tregistry but
// iverilog can't always resolve it at the static-init call site (the
// parameterized class spec lazy-elaboration may not have emitted it
// yet).  The path is otherwise covered by uvm_init's deferred-init
// queue, so the static-time no-op is safe.
//
// Pre-fix:
//   uvm_registry.svh:656: warning: Enable of unknown task
//     ``rgtry.initialize'' ignored (compile-progress fallback).
`timescale 1ns/1ps
`include "uvm_macros.svh"
import uvm_pkg::*;

class my_obj extends uvm_object;
  `uvm_object_utils(my_obj)
  function new(string name = "my_obj"); super.new(name); endfunction
endclass

module top;
  initial begin
    my_obj o = my_obj::type_id::create("o");
    if (o == null) $fatal(1, "FAIL: factory create returned null");
    $display("PASS: UVM compile clean of rgtry.initialize warning");
    $finish;
  end
endmodule
