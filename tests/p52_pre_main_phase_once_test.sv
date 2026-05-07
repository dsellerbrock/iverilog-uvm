// p52: G65 — pre_main_phase invoked exactly once
// Bug was: unique-override optimization in resolve_method_call_scope
// returned my_test::pre_main_phase causing non-virtual dispatch, so
// uvm_pre_main_phase.exec_task called it for every component.
// Fix: check task_def()->proc() == null before assuming no body.
`include "uvm_macros.svh"
import uvm_pkg::*;

class my_test extends uvm_test;
  `uvm_component_utils(my_test)
  int pre_main_count = 0;
  function new(string name="my_test", uvm_component parent=null);
    super.new(name, parent);
  endfunction
  task pre_main_phase(uvm_phase phase);
    pre_main_count++;
  endtask
  task main_phase(uvm_phase phase);
    phase.raise_objection(this);
    if (pre_main_count == 1)
      $display("PASS: pre_main_phase once p52");
    else
      $display("FAIL: pre_main_phase count=%0d", pre_main_count);
    phase.drop_objection(this);
  endtask
endclass

module top;
  initial run_test("my_test");
endmodule
