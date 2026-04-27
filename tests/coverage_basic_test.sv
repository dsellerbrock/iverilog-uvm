// Minimal SV coverage test: one covergroup, one coverpoint, sample once
`include "uvm_macros.svh"
import uvm_pkg::*;

class cov_item;
  rand byte unsigned val;
  covergroup cg;
    cp: coverpoint val {
      bins low  = {[0:63]};
      bins high = {[64:127]};
    }
  endgroup

  function new();
    cg = new();
  endfunction

  function void sample();
    cg.sample();
  endfunction

  function real get_coverage();
    return cg.get_inst_coverage();
  endfunction
endclass

class coverage_basic_test extends uvm_test;
  `uvm_component_utils(coverage_basic_test)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    cov_item item;
    real cov;
    phase.raise_objection(this);

    item = new();
    item.val = 8'd42;  // in low bin
    item.sample();

    cov = item.get_coverage();
    if (cov > 0.0)
      `uvm_info("COV_TEST", $sformatf("PASS: coverage=%.1f%%", cov), UVM_NONE)
    else
      `uvm_error("COV_TEST", $sformatf("FAIL: coverage=%.1f%%", cov))

    phase.drop_objection(this);
  endtask
endclass

module top;
  initial run_test("coverage_basic_test");
endmodule
