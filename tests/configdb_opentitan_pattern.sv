// Mimic OpenTitan's exact configdb pattern:
// 1. tb.sv sets via "*.env"
// 2. env build_phase passes cfg.assoc[key] as inout to get
interface clk_rst_if(input clk);
   logic data;
endinterface

import uvm_pkg::*;
`include "uvm_macros.svh"

class my_cfg extends uvm_object;
   `uvm_object_utils(my_cfg)
   virtual clk_rst_if clk_rst_vifs[string];
   function new(string name = "my_cfg"); super.new(name); endfunction
endclass

class my_env extends uvm_env;
   `uvm_component_utils(my_env)
   my_cfg cfg;

   function new(string name, uvm_component parent);
      super.new(name, parent);
   endfunction

   function void build_phase(uvm_phase phase);
      string ral_name = "uart_reg_block";
      string if_name = "clk_rst_vif";
      super.build_phase(phase);
      cfg = new("cfg");
      bit r;
      $display("DBG: before get, exists=%0d", cfg.clk_rst_vifs.exists(ral_name));
      r = uvm_config_db#(virtual clk_rst_if)::get(this, "", if_name,
                                                  cfg.clk_rst_vifs[ral_name]);
      $display("DBG: after get, r=%0d, exists=%0d, value_null=%0d",
               r, cfg.clk_rst_vifs.exists(ral_name),
               (cfg.clk_rst_vifs[ral_name] == null));
      if (!r) begin
         `uvm_fatal("NO_VIF", $sformatf("No clk_rst_if called %0s", ral_name))
      end
      $display("OPENTITAN PATTERN: PASS");
   endfunction
endclass

class my_test extends uvm_test;
   `uvm_component_utils(my_test)
   my_env env;
   function new(string name, uvm_component parent);
      super.new(name, parent);
   endfunction
   function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      env = my_env::type_id::create("env", this);
   endfunction
endclass

module top;
   bit clk;
   clk_rst_if dut_if(clk);

   initial begin
      clk = 0;
      forever #5 clk = ~clk;
   end

   initial begin
      // Exact OpenTitan tb.sv form:
      uvm_config_db#(virtual clk_rst_if)::set(null, "*.env", "clk_rst_vif", dut_if);
      run_test("my_test");
   end
endmodule
