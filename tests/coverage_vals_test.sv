// Coverage test with specific single-value bins
`include "uvm_macros.svh"
import uvm_pkg::*;

class cov_item;
  rand byte unsigned cmd;

  covergroup cg;
    cp_cmd: coverpoint cmd {
      bins read_cmd  = {8'd1};
      bins write_cmd = {8'd2};
      bins nop_cmd   = {8'd0};
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

class coverage_vals_test extends uvm_test;
  `uvm_component_utils(coverage_vals_test)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    cov_item item;
    real cov;
    phase.raise_objection(this);

    item = new();

    // Hit read_cmd bin
    item.cmd = 8'd1;
    item.sample();
    cov = item.get_coverage();
    `uvm_info("COV_TEST", $sformatf("After read_cmd: coverage=%.1f%%", cov), UVM_NONE)

    // Hit write_cmd bin
    item.cmd = 8'd2;
    item.sample();
    cov = item.get_coverage();
    `uvm_info("COV_TEST", $sformatf("After write_cmd: coverage=%.1f%%", cov), UVM_NONE)

    // Hit nop_cmd bin -> 100%
    item.cmd = 8'd0;
    item.sample();
    cov = item.get_coverage();

    if (cov > 99.0)
      `uvm_info("COV_TEST", $sformatf("PASS: full coverage=%.1f%%", cov), UVM_NONE)
    else
      `uvm_error("COV_TEST", $sformatf("FAIL: coverage=%.1f%%", cov))

    phase.drop_objection(this);
  endtask
endclass

module top;
  initial run_test("coverage_vals_test");
endmodule
