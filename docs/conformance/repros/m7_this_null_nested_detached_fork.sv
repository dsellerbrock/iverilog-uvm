// Minimal deterministic reproducer for issue #103 (the m7_objection_stress
// blocker). The implicit `this` in a detached (join_none) fork body nested
// inside another detached fork is NOT captured at spawn: it is read deferred
// and goes null for later loop iterations.
//
// Expected: every id prints "this.tag=77".
// Actual (bug): id=0,1 print 77; id>=2 print "THIS IS NULL".
//
// In UVM this makes uvm_phase_hopper::run_phases' per-phase drop_objection
// see a null `this`, so uvm_phase_hopper::get_objection() returns null and
// objection.drop_objection() silently no-ops on the null handle -> two
// phase-hopper objections (common.run, common.check) never drop -> the run
// never completes. See issue #103.
//
// Related: issue #102 (fixed) captures a single-branch `fork task(args);
// join_none` call's arguments at spawn, but only for a task-call child with
// the exact wrapped shape -- not a general inline detached fork body like
// the outer `fork begin for(...) ... end join_none` here.

module m7_this_null_nested_detached_fork;
  class Hopper;
    int tag = 77;
    task automatic obj_name(int id);
      #1;
      if (this == null) $display("id=%0d THIS IS NULL", id);
      else              $display("id=%0d this.tag=%0d", id, this.tag);
    endtask
    task automatic run();
      fork
        begin
          for (int i = 0; i < 6; i++) begin
            int id = i;
            fork begin this.obj_name(id); end join_none
            #1;
          end
        end
      join_none
      #50;
    endtask
  endclass
  initial begin Hopper h = new; h.run(); $finish(0); end
endmodule
