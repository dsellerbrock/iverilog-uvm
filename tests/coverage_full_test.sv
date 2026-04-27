// Comprehensive SV coverage test: multiple bins, 100% coverage, multiple coverpoints
`include "uvm_macros.svh"
import uvm_pkg::*;

class cov_item;
  rand byte unsigned val;
  rand byte unsigned prio;

  covergroup cg;
    cp_val: coverpoint val {
      bins low  = {[0:63]};
      bins high = {[64:127]};
    }
    cp_prio: coverpoint prio {
      bins lo_pri = {[0:31]};
      bins hi_pri = {[32:63]};
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

class coverage_full_test extends uvm_test;
  `uvm_component_utils(coverage_full_test)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    cov_item item;
    real cov;
    int pass_count;
    phase.raise_objection(this);

    item = new();
    pass_count = 0;

    // After 0 samples: coverage = 0
    cov = item.get_coverage();
    if (cov == 0.0)
      pass_count++;
    else
      `uvm_error("COV_TEST", $sformatf("FAIL 0%%: got %.1f%%", cov))

    // Sample: val=10 (low), prio=20 (lo_pri) -> 2/4 bins hit = 50%
    item.val  = 8'd10;
    item.prio = 8'd20;
    item.sample();
    cov = item.get_coverage();
    if (cov > 49.0 && cov < 51.0) begin
      pass_count++;
      `uvm_info("COV_TEST", $sformatf("50%% check: %.1f%%", cov), UVM_NONE)
    end else
      `uvm_error("COV_TEST", $sformatf("FAIL 50%%: got %.1f%%", cov))

    // Sample: val=100 (high), prio=50 (hi_pri) -> 4/4 bins hit = 100%
    item.val  = 8'd100;
    item.prio = 8'd50;
    item.sample();
    cov = item.get_coverage();
    if (cov > 99.0) begin
      pass_count++;
      `uvm_info("COV_TEST", $sformatf("100%% check: %.1f%%", cov), UVM_NONE)
    end else
      `uvm_error("COV_TEST", $sformatf("FAIL 100%%: got %.1f%%", cov))

    if (pass_count == 3)
      `uvm_info("COV_TEST", "PASS: all coverage checks passed", UVM_NONE)
    else
      `uvm_error("COV_TEST", $sformatf("FAIL: only %0d/3 checks passed", pass_count))

    phase.drop_objection(this);
  endtask
endclass

module top;
  initial run_test("coverage_full_test");
endmodule
