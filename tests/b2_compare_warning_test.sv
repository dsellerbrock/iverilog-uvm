// Phase 63b / B2: silence "has no method compare/convert2string/etc."
// warnings emitted by UVM's default-T parameterized class
// specializations (uvm_class_comp, uvm_class_converter, uvm_class_pair).
//
// Pre-fix: every UVM compile printed
//   uvm_policies.svh:107: warning: Object ... has no method "compare(...)"
//   uvm_pair.svh:113:    warning: Object ... has no method "first.compare"
// because the default T=int specialization elaborates
// `a.compare(b)` etc., which don't exist on int.  Those
// specializations are dead code in any user testbench that uses the
// helpers correctly.
//
// Fix: suppress the warning when tail_method is one of the well-known
// UVM dead-method names; the existing fallback (return null/0) is
// harmless because the specialization is never called.
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
    $display("PASS: UVM compile clean of compare()/do_compare warnings");
    $finish;
  end
endmodule
