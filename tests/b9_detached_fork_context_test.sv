// Phase 63b / B9: detached fork in a class task must retain access to
// the parent task's locals (and autotask captures) after the parent
// task returns.
//
// Pre-Phase 59: the FALLBACKS.md frontier reported
//   vthread_get_rd_context_item_scoped could not find a live automatic
//   context for scope=test.base_t.run_loop
// when an autotask child accessed parent locals after parent return.
//
// Phase 59 (commit 2d4432afb) pinned the autotask self frame in
// owned_context on fork.  Three reproducer shapes that previously
// failed now pass:
//
//   1. fork ... automatic T cap = parent_local; ... join_none
//   2. fork ... begin /*reads*/ parent_local; end join_none
//      (parent local NOT automatic-captured)
//   3. nested forks with multiple autotask frames in a chain
//
// This test pins all three down as regression coverage so a future
// scheduler change doesn't silently undo the fix.
`timescale 1ns/1ps

class item_t;
  int id;
  function new(int i); id = i; endfunction
endclass

class test_t;
  // Case 1: automatic-captured local
  task run_capture;
    item_t ph;
    ph = new(42);
    fork
      automatic item_t phase = ph;
      begin
        #10;
        if (phase == null) $fatal(1, "FAIL/B9-1: autotask capture lost");
        if (phase.id != 42) $fatal(1, "FAIL/B9-1: phase.id=%0d", phase.id);
      end
    join_none
  endtask

  // Case 2: parent-local without explicit capture
  task run_local;
    item_t ph;
    ph = new(99);
    fork
      begin
        #10;
        if (ph == null) $fatal(1, "FAIL/B9-2: parent local null after parent return");
        if (ph.id != 99) $fatal(1, "FAIL/B9-2: ph.id=%0d", ph.id);
      end
    join_none
  endtask

  // Case 3: nested forks with chained autotask frames
  task inner(item_t arg);
    fork
      begin
        #10;
        if (arg == null) $fatal(1, "FAIL/B9-3: inner arg null");
        if (arg.id != 11) $fatal(1, "FAIL/B9-3: inner arg.id=%0d", arg.id);
      end
    join_none
  endtask
  task run_nested;
    item_t local_item;
    local_item = new(11);
    fork
      automatic item_t cap = local_item;
      begin
        #5;
        inner(cap);
      end
    join_none
  endtask
endclass

module top;
  test_t t;
  initial begin
    t = new();
    t.run_capture();
    t.run_local();
    t.run_nested();
    #200;
    $display("PASS: detached-fork autotask context retention");
    $finish;
  end
endmodule
