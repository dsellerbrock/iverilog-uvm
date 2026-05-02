// Test config_db get with output arg into an assoc array entry —
// the OpenTitan dv_base_env pattern: cfg.clk_rst_vifs[ral_name] = ...
interface simple_if(input clk);
   logic data;
endinterface

import uvm_pkg::*;
`include "uvm_macros.svh"

class my_cfg extends uvm_object;
   `uvm_object_utils(my_cfg)
   virtual simple_if vifs[string];
   function new(string name = "my_cfg"); super.new(name); endfunction
endclass

class my_env extends uvm_env;
   `uvm_component_utils(my_env)
   my_cfg cfg;

   function new(string name, uvm_component parent);
      super.new(name, parent);
   endfunction

   function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      cfg = new("cfg");
      // exact OpenTitan pattern: get into assoc array entry
      if (!uvm_config_db#(virtual simple_if)::get(this, "", "my_vif", cfg.vifs["entry"])) begin
         `uvm_fatal("NO_VIF", "vif not found")
      end
      $display("get succeeded, cfg.vifs[entry] is %s",
               (cfg.vifs.exists("entry") ? "set" : "missing"));
      if (cfg.vifs.exists("entry"))
         $display("CONFIGDB ASSOC: PASS");
      else
         $display("CONFIGDB ASSOC: FAIL");
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
   simple_if dut_if(clk);
   initial forever #5 clk = ~clk;
   initial begin
      uvm_config_db#(virtual simple_if)::set(null, "*.env", "my_vif", dut_if);
      run_test("my_test");
   end
endmodule
