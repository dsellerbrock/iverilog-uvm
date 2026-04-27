// Test config_db get with output arg into a class property (not assoc).
interface simple_if(input clk);
   logic data;
endinterface

import uvm_pkg::*;
`include "uvm_macros.svh"

class my_cfg extends uvm_object;
   `uvm_object_utils(my_cfg)
   virtual simple_if vif;
   function new(string name = "my_cfg"); super.new(name); endfunction
endclass

class my_env extends uvm_env;
   `uvm_component_utils(my_env)
   my_cfg cfg;
   function new(string name, uvm_component parent); super.new(name, parent); endfunction
   function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      cfg = new("cfg");
      if (!uvm_config_db#(virtual simple_if)::get(this, "", "my_vif", cfg.vif))
         `uvm_fatal("NO_VIF", "vif not found")
      else if (cfg.vif == null) $display("CLASSPROP: FAIL — null after get");
      else                       $display("CLASSPROP: PASS");
   endfunction
endclass

class my_test extends uvm_test;
   `uvm_component_utils(my_test)
   my_env env;
   function new(string name, uvm_component parent); super.new(name, parent); endfunction
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
