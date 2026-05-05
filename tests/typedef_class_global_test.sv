// Phase 62 / I2: package-global class handles whose class is defined
// AFTER the variable's declaration must be elaborated as `.var/cobj`,
// not `.var/i` (logic vector).  The post-elab repair pass in
// `NetScope::repair_typed_class_signals` patches NetNet types after all
// classes are visible, before statement elab emits assignments against
// them.
`timescale 1ns/1ps
package mypkg;
  // Forward declaration before variable.
  typedef class C;
  C g_handle;

  // Function that assigns the global.
  function void init();
    g_handle = new();
  endfunction

  // Class definition comes AFTER the variable declaration — this is
  // the pattern UVM uses for uvm_default_table_printer in
  // uvm_object_globals.svh.
  class C;
    int data;
    function new();
      data = 42;
    endfunction
  endclass
endpackage

module top;
  import mypkg::*;
  initial begin
    init();
    if (g_handle == null) begin
      $display("FAIL: g_handle is NULL after init() (typeref-to-class wire emitted as logic vector)");
      $fatal(1, "I2 regression: package-global class handle assignment dropped");
    end
    if (g_handle.data != 42) begin
      $display("FAIL: g_handle.data = %0d (expected 42)", g_handle.data);
      $fatal(1, "I2 regression: assignment did not propagate");
    end
    $display("PASS: g_handle is non-null, g_handle.data = %0d", g_handle.data);
    $finish;
  end
endmodule
