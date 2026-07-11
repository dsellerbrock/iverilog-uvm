// G66 reproducer (VERIFIED-FAILS 2026-07-11): declaring a
// compilation-unit class whose name collides with identifiers used
// inside uvm_pkg (here: `comp`, used as variable/port names in the UVM
// phase traversal code) breaks elaboration of the UNRELATED package
// code once the class participates in a parameterized specialization
// (uvm_callbacks#(comp, my_cb)).
//
// Errors observed:
//   error: Unable to bind variable `comp' in `uvm_pkg.uvm_bottomup_phase.traverse...'
//   error: No function named `comp_type.comp' found ...
//
// Renaming the class (e.g. `my_comp`) makes the identical test pass —
// see tests/m2_uvm_register_cb_test.sv.
//
// Simple reductions (plain shadowing of package-local variables/ports
// by a $unit class name, even derived from a package base) PASS, so
// the defect is specific to specialization-time re-elaboration.
// IEEE 1800-2017 3.12.1 (compilation units), 23.9 (scope rules),
// 8.25 (parameterized classes).
//
// Run: iverilog -g2012 -I uvm-core/src -DUVM_NO_DPI uvm-core/src/uvm_pkg.sv <this file>
// Expected once fixed: prints "PASS g66-uvm".
import uvm_pkg::*;
`include "uvm_macros.svh"

class my_cb extends uvm_callback;
  function new(string name = "my_cb");
    super.new(name);
  endfunction
  virtual function void on_event(int x);
  endfunction
endclass

class comp extends uvm_component;   // <-- colliding name is the trigger
  `uvm_component_utils(comp)
  `uvm_register_cb(comp, my_cb)
  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction
  function void hit(int x);
    `uvm_do_callbacks(comp, my_cb, on_event(x))
  endfunction
endclass

class counting_cb extends my_cb;
  int count = 0;
  function new(string name = "counting_cb");
    super.new(name);
  endfunction
  virtual function void on_event(int x);
    count = count + x;
  endfunction
endclass

module g66_unit_class_name_collision_uvm;
  initial begin
    comp c;
    counting_cb cb;
    c = new("c", null);
    cb = new("cb");
    uvm_callbacks#(comp, my_cb)::add(c, cb);
    c.hit(3);
    c.hit(4);
    if (cb.count == 7) $display("PASS g66-uvm");
    else $display("FAIL g66-uvm count=%0d expected 7", cb.count);
    $finish;
  end
endmodule
