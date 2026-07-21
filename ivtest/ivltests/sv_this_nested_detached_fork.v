// A reference to `this` from a detached (join_none) fork body nested inside
// another detached fork used to resolve to NULL for later loop iterations:
// the forked thread's inherited automatic-context chain no longer linked
// back to the owning activation frame, so the scoped read of `this` missed
// and returned null.
//
// This was the root cause of the UVM m7_objection_stress hang
// (uvm_phase_hopper::run_phases drops each phase's objection inside exactly
// this fork shape; for the later phases `this` went null, get_objection()
// returned null, and drop_objection() silently no-op'd on the null handle).
//
// Fixed by a strictly-additive last-resort fallback in
// vthread_get_rd_context_item_scoped: when every context-chain walk fails,
// resolve to the target automatic scope's single live activation. `this`
// (the method receiver) always has a single live activation for a
// non-recursive method, so this is unambiguous.
//
// Each spawned worker checks `this` and, if valid, bumps a counter that is
// itself a member of `this`. PASSED only if every worker (across a
// single-level and a nested detached fork) saw a live `this`.

module sv_this_nested_detached_fork;

  localparam int N = 6;

  class Runner;
    int tag = 77;
    int nested_seen = 0;   // bumped by each nested-fork worker that saw this.tag==77
    int single_seen = 0;   // bumped by each single-fork worker that saw this.tag==77

    task automatic single_worker();
      #1;
      if (this != null && this.tag == 77) this.single_seen++;
    endtask

    // Nested: an outer detached fork runs the loop; each iteration spawns an
    // inner detached fork whose body reads `this` directly.
    task automatic run_nested();
      fork
        begin
          for (int i = 0; i < N; i++) begin
            fork
              begin #1; if (this != null && this.tag == 77) this.nested_seen++; end
            join_none
            #1;
          end
        end
      join_none
      #(3*N);
    endtask

    // Single-level: a detached fork calling a method (implicit this arg).
    task automatic run_single();
      for (int i = 0; i < N; i++) begin
        fork single_worker(); join_none
        #1;
      end
      #(3*N);
    endtask
  endclass

  int errors = 0;

  initial begin
    Runner r = new;
    r.run_nested();
    r.run_single();

    if (r.nested_seen !== N) begin
      $display("FAIL: nested workers saw live this %0d/%0d times", r.nested_seen, N);
      errors++;
    end
    if (r.single_seen !== N) begin
      $display("FAIL: single workers saw live this %0d/%0d times", r.single_seen, N);
      errors++;
    end

    if (errors == 0) $display("PASSED");
    else $display("FAILED (%0d errors)", errors);
    $finish(0);
  end

endmodule
