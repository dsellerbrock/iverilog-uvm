`include "uvm_macros.svh"
import uvm_pkg::*;

class guard_endless_seq extends uvm_sequence;
  `uvm_object_utils(guard_endless_seq)
  uvm_phase phase_h;

  function new(string name = "guard_endless_seq");
    super.new(name);
  endfunction

  task body();
    #5;
    phase_h.drop_objection(this);
    forever #1;
  endtask
endclass

class guard_join_test extends uvm_test;
  `uvm_component_utils(guard_join_test)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    guard_endless_seq seq;
    seq = guard_endless_seq::type_id::create("seq");
    phase.raise_objection(seq);
    seq.phase_h = phase;
    seq.start(null);
    `uvm_fatal("GUARD_RESUME",
               "sequence start returned after its guarded process was killed")
  endtask

  function void report_phase(uvm_phase phase);
    super.report_phase(phase);
    $display("PASS: process-guard self-kill unwound synchronous frames");
  endfunction
endclass

module top;
  initial run_test("guard_join_test");
endmodule
