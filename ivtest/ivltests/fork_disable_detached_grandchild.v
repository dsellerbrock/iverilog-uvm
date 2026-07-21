// Reaping a fork subtree with a still-live detached grandchild must not
// double-process the grandchild during `disable fork`.
//
// Pattern: a forked worker itself spawns a detached (join_none) grandchild
// that waits on an event; the worker also waits on the same event. The
// event fires, join_any completes, and `disable fork` tears the subtree
// down. Previously vthread_reap left the reaped thread's child sets
// populated, so of_DISABLE_FORK (which reaps a detached child that
// do_disable had already reaped) re-processed the grandchild with a
// rewritten parent pointer and tripped `child->parent == thr`.
//
// No class events involved -- this exercises the generic scheduler.
// Prints PASSED if it reaches the end without the assertion abort.

module fork_disable_detached_grandchild;
  event ev;

  task automatic worker();
    fork
      begin @(ev); end          // detached grandchild, still live at teardown
    join_none
    @(ev);                      // the worker also waits
  endtask

  initial begin
    fork
      worker();
      begin #5 -> ev; end
    join_any
    disable fork;               // must reap the subtree cleanly
    #10 $display("PASSED");
    $finish(0);
  end
endmodule
