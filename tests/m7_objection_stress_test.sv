// M7 stress: objection machinery under concurrent raise/drop traffic.
//  - 8 forked workers each raise/drop the run-phase objection with
//    staggered delays (longest finishes at t=80);
//  - a child component raises with an explicit count of 3 and drops
//    one at a time from its own run_phase;
//  - the main run_phase process holds its own objection while it waits
//    for every worker and the child to finish, then verifies counts
//    and that the last worker released at exactly t=80.
//
// NOTE: the verification runs at the END of run_phase, not in
// report_phase: post-run function phases (extract/check/report/final)
// currently never execute because class event properties are shared
// per-class (see the class-event warning in elab_scope.cc) which
// falsely wakes the phase hopper's ALL_DROPPED waiter. Recorded gap;
// do not move these checks to report_phase until that is fixed.
`timescale 1ns/1ns
`include "uvm_macros.svh"
import uvm_pkg::*;

class m7_obj_child extends uvm_component;
  `uvm_component_utils(m7_obj_child)
  int unsigned drops_done = 0;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    phase.raise_objection(this, "child batch", 3);
    repeat (3) begin
      #15;
      phase.drop_objection(this, "child batch");
      drops_done += 1;
    end
  endtask
endclass

class m7_objection_stress extends uvm_test;
  `uvm_component_utils(m7_objection_stress)
  m7_obj_child child;
  int unsigned workers_done = 0;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    child = m7_obj_child::type_id::create("child", this);
  endfunction

  task worker(uvm_phase phase, int unsigned idx);
    phase.raise_objection(this, $sformatf("worker %0d", idx));
    #(10 * (idx + 1));
    workers_done += 1;
    phase.drop_objection(this, $sformatf("worker %0d", idx));
  endtask

  task run_phase(uvm_phase phase);
    phase.raise_objection(this, "main checker");
    for (int unsigned i = 0; i < 8; i++) begin
      automatic int unsigned idx = i;
      fork
        worker(phase, idx);
      join_none
    end

    // The wait returns exactly when the slowest worker (t=80) and the
    // child (t=45) have both finished. The counter check lives here;
    // the TIME check lives in the module's final block, because $time
    // compared numerically inside a $unit class is unreliable (finding
    // 3 in m7_stress_findings_2026-07-18.md).
    wait (workers_done == 8 && child.drops_done == 3);
    if (workers_done == 8 && child.drops_done == 3)
      $display("PASS: objection stress counters (workers=%0d child_drops=%0d)",
               workers_done, child.drops_done);
    else
      $display("FAIL: workers=%0d (want 8) child_drops=%0d (want 3)",
               workers_done, child.drops_done);
    phase.drop_objection(this, "main checker");
  endtask
endclass

module m7_objection_stress_test;
  import uvm_pkg::*;
  initial run_test("m7_objection_stress");

  // The UVM run ends (uvm_root $finish) when the last objection drops,
  // so end-of-simulation time proves the phase was held open exactly
  // until the slowest worker released at t=80.
  final begin
    if ($time == 80)
      $display("PASS: objection stress held run_phase to t=%0t", $time);
    else
      $display("FAIL: simulation ended at t=%0t (want 80)", $time);
  end
endmodule
