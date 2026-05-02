// Repro of OpenTitan dv_base_test cast pattern using non-parametric test.
//
// Tests that $cast(typed, base_handle) succeeds when base_handle was created
// via uvm_object_wrapper.create_object().
module top;
   import uvm_pkg::*;
`include "uvm_macros.svh"

   class my_cfg extends uvm_object;
      int n = 42;
      `uvm_object_utils(my_cfg)
      function new(string name = "my_cfg"); super.new(name); endfunction
   endclass

   class my_test extends uvm_test;
      `uvm_component_utils(my_test)

      typedef my_cfg CFG_T;
      CFG_T cfg;

      function new(string name = "my_test", uvm_component parent = null);
         super.new(name, parent);
      endfunction

      virtual function void build_phase(uvm_phase phase);
         uvm_object_wrapper cfg_type;
         uvm_object base_cfg;
         super.build_phase(phase);

         cfg_type = CFG_T::get_type();
         $display("cfg_type name='%s'", cfg_type.get_type_name());

         base_cfg = cfg_type.create_object("cfg");
         if (base_cfg == null) begin
            $display("FAIL: create_object returned null");
            return;
         end
         $display("base_cfg created, type='%s'", base_cfg.get_type_name());

         if (!$cast(cfg, base_cfg)) begin
            $display("FAIL: $cast(cfg, base_cfg) failed");
            return;
         end
         $display("cast OK; cfg.n=%0d", cfg.n);
         $display("FACTORY CAST: PASS");
      endfunction
   endclass

   initial run_test("my_test");
endmodule
