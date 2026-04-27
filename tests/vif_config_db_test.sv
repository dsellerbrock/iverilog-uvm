// Test uvm_config_db #(virtual interface) set/get pattern
interface simple_if;
  logic clk;
  logic [7:0] data;
endinterface

import uvm_pkg::*;
`include "uvm_macros.svh"

class my_driver extends uvm_driver #(uvm_sequence_item);
  `uvm_component_utils(my_driver)
  virtual simple_if vif;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db #(virtual simple_if)::get(this, "", "vif", vif))
      `uvm_fatal("NO_VIF", "Virtual interface not found in config_db")
  endfunction

  task run_phase(uvm_phase phase);
    phase.raise_objection(this);
    @(posedge vif.clk);
    `uvm_info("DRV", $sformatf("saw posedge, data=%0h", vif.data), UVM_LOW)
    phase.drop_objection(this);
  endtask
endclass

class my_test extends uvm_test;
  `uvm_component_utils(my_test)
  my_driver drv;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    drv = my_driver::type_id::create("drv", this);
  endfunction
endclass

module top;
  simple_if dut_if();

  initial begin
    dut_if.clk  = 0;
    dut_if.data = 8'hAB;
    forever #5 dut_if.clk = ~dut_if.clk;
  end

  initial begin
    uvm_config_db #(virtual simple_if)::set(null, "uvm_test_top.drv", "vif", dut_if);
    run_test("my_test");
  end
endmodule
