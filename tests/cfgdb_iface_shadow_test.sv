// Phase 47: parameterized class specialization key now uses the bare type
// name for interface types, instead of class_scope path. The Phase 45/46
// fixes attach the interface's instance scope as `class_scope_` lazily; the
// previous label generator picked that up via `scope_path(class_scope)`,
// which made `<class-type:clk_rst_if>` and `<class-type:tb.clk_rst_if>`
// hash to different specialization cache entries even though both are the
// same `virtual <iface>` parameter. Two separate netclass_t instances of
// `uvm_resource#(virtual clk_rst_if)` were created -> their static
// `my_type` instances differed -> uvm_config_db type filter never matched
// at runtime, even though name+scope matched.

`include "uvm_macros.svh"
import uvm_pkg::*;

interface clk_rst_if(inout clk, inout rst_n);
  bit drive;
endinterface

class env_t extends uvm_env;
  `uvm_component_utils(env_t)
  function new(string name="env", uvm_component parent=null);
    super.new(name, parent);
  endfunction
  virtual function void build_phase(uvm_phase phase);
    virtual clk_rst_if vif_h;
    bit got;
    super.build_phase(phase);
    got = uvm_config_db#(virtual clk_rst_if)::get(this, "", "clk_rst_vif", vif_h);
    if (got) $display("PASS got=%0d vif!=null=%0d", got, vif_h != null);
    else $display("FAIL got=0");
  endfunction
endclass

class test_t extends uvm_test;
  `uvm_component_utils(test_t)
  env_t env;
  function new(string name="test", uvm_component parent=null);
    super.new(name, parent);
  endfunction
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    env = env_t::type_id::create("env", this);
  endfunction
  task run_phase(uvm_phase phase);
    phase.raise_objection(this);
    #1;
    phase.drop_objection(this);
  endtask
endclass

module top;
  wire clk, rst_n;
  // Instance name == interface type name -- the OpenTitan tb pattern.
  clk_rst_if clk_rst_if(.clk, .rst_n);
  initial begin
    uvm_config_db#(virtual clk_rst_if)::set(null, "*.env", "clk_rst_vif", clk_rst_if);
    run_test("test_t");
    $finish;
  end
endmodule
