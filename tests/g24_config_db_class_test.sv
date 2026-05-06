// G24 regression: uvm_config_db#(class_obj)::get for class-typed objects.
// Verifies set/get round-trip preserves class handle and field values.
`include "uvm_macros.svh"
import uvm_pkg::*;

class g24_cfg extends uvm_object;
  `uvm_object_utils(g24_cfg)
  int value;
  function new(string name = "g24_cfg"); super.new(name); endfunction
endclass

module top;
  initial begin
    g24_cfg cfg_set, cfg_get;
    int ok;

    cfg_set = new("cfg_set");
    cfg_set.value = 42;

    uvm_config_db#(g24_cfg)::set(null, "*", "g24_key", cfg_set);
    ok = uvm_config_db#(g24_cfg)::get(null, "", "g24_key", cfg_get);

    if (!ok || cfg_get == null || cfg_get.value != 42) begin
      $display("FAIL");
      $finish;
    end
    $display("PASS");
    $finish;
  end
endmodule
