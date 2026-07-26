// M7 / issue #98 acceptance: the post-run function phases must all
// execute after a run_phase held open by CONCURRENT objection traffic.
//
// m7_objection_stress_test proves the run ends at the right TIME. This
// test proves the rest of the phase schedule survives it: while the
// phase-hopper objection failed to all-drop to uvm_root, run_phases()
// never returned and extract/check/report/final never ran at all -- the
// symptom the issue records as "the post-run function phases were
// documented as never executing".
//
// The objection traffic is deliberately concurrent and multi-level:
// eight workers on the test's own objection, a child component raising
// with an explicit count of 3 and dropping one at a time, and a
// grandchild that raises and drops inside the child's subtree so the
// count has to propagate two levels up to uvm_root and back to zero.
`timescale 1ns/1ns
`include "uvm_macros.svh"
import uvm_pkg::*;

class m7_prp_grandchild extends uvm_component;
  `uvm_component_utils(m7_prp_grandchild)
  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction
  task run_phase(uvm_phase phase);
    phase.raise_objection(this, "grandchild");
    #35;
    phase.drop_objection(this, "grandchild");
  endtask
endclass

class m7_prp_child extends uvm_component;
  `uvm_component_utils(m7_prp_child)
  m7_prp_grandchild gc;
  int unsigned drops_done = 0;
  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction
  function void build_phase(uvm_phase phase);
    gc = m7_prp_grandchild::type_id::create("gc", this);
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

class m7_post_run_phases extends uvm_test;
  `uvm_component_utils(m7_post_run_phases)
  m7_prp_child child;
  int unsigned workers_done = 0;

  // One bit per post-run phase, in schedule order.
  bit ran_extract = 0;
  bit ran_check   = 0;
  bit ran_report  = 0;
  bit ran_final   = 0;
  int unsigned order = 0;
  int unsigned at_extract = 0, at_check = 0, at_report = 0, at_final = 0;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    child = m7_prp_child::type_id::create("child", this);
  endfunction

  task worker(uvm_phase phase, int unsigned idx);
    phase.raise_objection(this, $sformatf("worker %0d", idx));
    #(10 * (idx + 1));
    workers_done += 1;
    phase.drop_objection(this, $sformatf("worker %0d", idx));
  endtask

  task run_phase(uvm_phase phase);
    phase.raise_objection(this, "main");
    for (int unsigned i = 0; i < 8; i++) begin
      automatic int unsigned idx = i;
      fork
        worker(phase, idx);
      join_none
    end
    wait (workers_done == 8 && child.drops_done == 3);
    phase.drop_objection(this, "main");
  endtask

  function void extract_phase(uvm_phase phase);
    ran_extract = 1; order++; at_extract = order;
  endfunction
  function void check_phase(uvm_phase phase);
    ran_check = 1; order++; at_check = order;
  endfunction
  function void report_phase(uvm_phase phase);
    ran_report = 1; order++; at_report = order;
  endfunction
  function void final_phase(uvm_phase phase);
    ran_final = 1; order++; at_final = order;
    if (!ran_extract || !ran_check || !ran_report)
      $display("FAIL: post-run phases ran extract=%0b check=%0b report=%0b",
               ran_extract, ran_check, ran_report);
    else if (!(at_extract == 1 && at_check == 2 && at_report == 3 && at_final == 4))
      $display("FAIL: post-run phase order extract=%0d check=%0d report=%0d final=%0d (want 1,2,3,4)",
               at_extract, at_check, at_report, at_final);
    else if (workers_done != 8 || child.drops_done != 3)
      $display("FAIL: objection counters workers=%0d child_drops=%0d",
               workers_done, child.drops_done);
    else
      $display("PASS: all post-run phases executed in order after concurrent objections");
  endfunction
endclass

module m7_post_run_phases_test;
  import uvm_pkg::*;
  initial run_test("m7_post_run_phases");

  // The slowest worker releases at t=80; the grandchild at t=35 and the
  // child's last drop at t=45 are both covered by it. The run must not
  // extend past that -- the watchdog would.
  final begin
    if ($time == 80)
      $display("PASS: run_phase ended at t=%0t", $time);
    else
      $display("FAIL: simulation ended at t=%0t (want 80)", $time);
  end
endmodule
