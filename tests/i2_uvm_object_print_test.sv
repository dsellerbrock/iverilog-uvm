// Phase 62 / I2: uvm_object.print() must dispatch through the
// uvm_default_table_printer global without a vdispatch error.
//
// Pre-fix: uvm_default_table_printer (declared after a forward
// `typedef class uvm_table_printer;` in uvm_object_globals.svh) was
// elaborated as `.var/i` (logic vector) instead of `.var/cobj`
// because PWire::elaborate_sig fired before add_class registered
// uvm_table_printer.  Statement elab then compiled
// `uvm_default_table_printer = new()` as `%null; %store/obj`
// (number-fallback), silently no-op'd.  obj.print() then crashed
// with `vdispatch: this is not a cobject for uvm_pkg::uvm_printer.emit`.
//
// Fix (iverilog 922c2181e): post-elaborate_sig, pre-statement-elab
// repair pass `NetScope::repair_typed_class_signals` patches the
// NetNet's net_type after all classes are visible.
`timescale 1ns/1ps
`include "uvm_macros.svh"
import uvm_pkg::*;

class my_data extends uvm_object;
  int x = 42;
  `uvm_object_utils(my_data)
  function new(string name = "my_data");
    super.new(name);
  endfunction
endclass

module top;
  initial begin
    my_data d;
    // Trigger uvm_init via factory call.  Pre-fix:
    // uvm_default_table_printer was elaborated as `.var/i` (vector)
    // so the assignment in uvm_init silently no-op'd via number-cast
    // fallback, leaving it null after init.
    d = my_data::type_id::create("d");
    if (uvm_default_table_printer == null) begin
      $display("FAIL: uvm_default_table_printer is null after uvm_init");
      $fatal(1, "I2 regression: forward-typedef'd class global lost");
    end
    d.print();
    $display("PASS: uvm_object.print() dispatched through default printer");
    $finish;
  end
endmodule
