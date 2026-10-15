`timescale 1ns/1ps
`include "uvm_macros.svh"
import uvm_pkg::*;

class perf_item extends uvm_sequence_item;
  int value;
  `uvm_object_utils(perf_item)
  function new(string name = "perf_item"); super.new(name); endfunction
endclass

class config_pressure extends uvm_component;
  int observed;
  `uvm_component_utils(config_pressure)
  function new(string name, uvm_component parent); super.new(name, parent); endfunction
  function void build_phase(uvm_phase phase);
    int value;
    perf_item item;
    for (int i = 0; i < 256; i++) begin
      string field = $sformatf("setting_%0d", i);
      uvm_config_db#(int)::set(this, "", field, i ^ 32'h5a5a);
      if (!uvm_config_db#(int)::get(this, "", field, value))
        `uvm_fatal("WP0", $sformatf("missing %s", field))
      observed += value;
      item = perf_item::type_id::create($sformatf("item_%0d", i));
      item.value = value;
      `uvm_info("WP0", $sformatf("item=%0d value=%0d", i, value), UVM_LOW)
    end
  endfunction
endclass

class config_factory_test extends uvm_test;
  config_pressure pressure;
  `uvm_component_utils(config_factory_test)
  function new(string name, uvm_component parent); super.new(name, parent); endfunction
  function void build_phase(uvm_phase phase);
    pressure = config_pressure::type_id::create("pressure", this);
  endfunction
  function void report_phase(uvm_phase phase);
    `uvm_info("WP0", $sformatf("observed=%0d", pressure.observed), UVM_NONE)
  endfunction
endclass

module top;
  initial run_test("config_factory_test");
endmodule
