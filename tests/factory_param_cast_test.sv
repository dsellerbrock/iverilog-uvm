// Repro of OpenTitan dv_base_test cast pattern using non-parametric test.
//
// Tests that $cast(typed, base_handle) succeeds when base_handle was created
// via uvm_object_wrapper.create_object().
`include "uvm_macros.svh"

package transfer_types_pkg;
   import uvm_pkg::*;

   class transfer_base extends uvm_sequence_item;
      `uvm_object_utils(transfer_base)
      function new(string name = "transfer_base"); super.new(name); endfunction
   endclass

   class parameterized_transfer #(
      parameter int NUM_MASTERS = 1,
      parameter int MASTER_BITS = 1,
      parameter int NUM_SLAVES = 1,
      parameter int ADDRESS_WIDTH = 32,
      parameter int WDATA_WIDTH = 32,
      parameter int RDATA_WIDTH = 32
   ) extends transfer_base;
      localparam int DATA_WIDTH = WDATA_WIDTH > RDATA_WIDTH ? WDATA_WIDTH : RDATA_WIDTH;
      `uvm_object_param_utils(parameterized_transfer #(NUM_MASTERS, MASTER_BITS,
         NUM_SLAVES, ADDRESS_WIDTH, WDATA_WIDTH, RDATA_WIDTH))
      function new(string name = "parameterized_transfer"); super.new(name); endfunction
   endclass
endpackage

package transfer_params_pkg;
   class transfer_params;
      localparam int NUM_MASTERS = 1;
      localparam int MASTER_BITS = 1;
      localparam int NUM_SLAVES = 1;
      localparam int ADDRESS_WIDTH = 32;
      localparam int WDATA_WIDTH = 32;
      localparam int RDATA_WIDTH = 32;
   endclass
endpackage

package transfer_alias_pkg;
   typedef transfer_types_pkg::parameterized_transfer #(1, 1, 1, 32, 32, 32)
      transfer_alias_t;
   typedef transfer_types_pkg::parameterized_transfer #(
      transfer_params_pkg::transfer_params::NUM_MASTERS,
      transfer_params_pkg::transfer_params::MASTER_BITS,
      transfer_params_pkg::transfer_params::NUM_SLAVES,
      transfer_params_pkg::transfer_params::ADDRESS_WIDTH,
      transfer_params_pkg::transfer_params::WDATA_WIDTH,
      transfer_params_pkg::transfer_params::RDATA_WIDTH
   ) generated_transfer_t;
   typedef transfer_types_pkg::parameterized_transfer #(1, 1, 1, 64, 32, 32)
      other_transfer_t;
endpackage

module top;
   import uvm_pkg::*;

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
         transfer_types_pkg::transfer_base base_transfer;
         transfer_alias_pkg::transfer_alias_t alias_transfer;
         transfer_alias_pkg::generated_transfer_t generated_transfer;
         transfer_alias_pkg::other_transfer_t other_transfer;
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

         generated_transfer = transfer_alias_pkg::generated_transfer_t::type_id::create("transfer");
         base_transfer = generated_transfer;
         if (base_transfer.get_object_type() != transfer_alias_pkg::transfer_alias_t::type_id::get())
            `uvm_fatal("CAST", "parameterized transfer factory wrappers differ")
         if (!$cast(alias_transfer, base_transfer))
            `uvm_fatal("CAST", "typedef alias cast failed with class localparam")
         if (!$cast(generated_transfer, base_transfer))
            `uvm_fatal("CAST", "generated typedef self-cast failed")
         if ($cast(other_transfer, base_transfer))
            `uvm_fatal("CAST", "cast accepted a different parameter specialization")
         if (generated_transfer.DATA_WIDTH != 32)
            `uvm_fatal("CAST", "class localparam did not evaluate from specialization")
         $display("PARAMETERIZED FACTORY CAST: PASS");
         $display("FACTORY CAST: PASS");
      endfunction
   endclass

   initial run_test("my_test");
endmodule
