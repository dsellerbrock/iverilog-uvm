// Reproduce OpenTitan tb.sv pattern: config_db set with wildcard "*.env"
// then get from a deeper component "uvm_test_top.env".
interface simple_if(input clk);
   logic data;
endinterface

import uvm_pkg::*;
`include "uvm_macros.svh"

class my_env extends uvm_env;
   `uvm_component_utils(my_env)
   virtual simple_if vif;

   function new(string name, uvm_component parent);
      super.new(name, parent);
   endfunction

   function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      if (!uvm_config_db#(virtual simple_if)::get(this, "", "my_vif", vif))
         `uvm_fatal("NO_VIF", "Virtual interface not found via wildcard")
      else
         $display("CONFIGDB WILDCARD: PASS");
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

   initial begin
      clk = 0;
      forever #5 clk = ~clk;
   end

   initial begin
      // Wildcard set: should match uvm_test_top.env
      uvm_config_db#(virtual simple_if)::set(null, "*.env", "my_vif", dut_if);
      run_test("my_test");
   end
endmodule
