// A nested call frame whose leaf is blocked on a resource.
//
// Resource waits used to be invisible to the scheduler. A leaf parked in
// mailbox.get() or semaphore.get() has is_scheduled == 0,
// waiting_for_event == 0 and no children, so every predicate that asks
// "is this thread blocked, or may it be driven?" answered "may be driven":
// process::status() reported such a process RUNNING, and the synchronous
// call-frame drain treated the leaf as runnable and re-entered its blocking
// opcode, registering a second wait record for an already-parked thread.
//
// A single blocked-on-wait predicate now covers event waits and resource
// waits alike. This test pins the observable half -- the state a nested
// blocked leaf reports while its parent frame is parked on it -- and that
// each leaf still resumes exactly once afterwards.
module sv_resource_wait_sync_nested;

  localparam int FINISHED = 0, RUNNING = 1, WAITING = 2, SUSPENDED = 3, KILLED = 4;

  mailbox #(int) mbx;
  semaphore      sem;
  process        mbx_leaf, sem_leaf;

  int errors = 0;
  int mbx_leaf_runs = 0;
  int sem_leaf_runs = 0;
  int leaf_v = 0;
  int mbx_leaf_status = -1;
  int sem_leaf_status = -1;

  task automatic chk(string what, int actual, int wanted);
    if (actual !== wanted) begin
      $display("FAILED %0s: got %0d exp %0d", what, actual, wanted);
      errors++;
    end
  endtask

  // Called from the initial block, so its leaves are nested one call frame
  // down. It forks leaves that park on a mailbox and a semaphore, then parks
  // itself in the join -- the state in which the caller's drain goes looking
  // for something runnable in the child tree.
  task automatic outer_frame();
    fork
      begin
        mbx_leaf = process::self();
        mbx.get(leaf_v);
        mbx_leaf_runs++;
      end
      begin
        sem_leaf = process::self();
        sem.get(1);
        sem_leaf_runs++;
      end
      begin
        // Sample the leaves' state from inside the same frame, while both
        // are parked and the frame itself is joining on them.
        #1;
        mbx_leaf_status = mbx_leaf.status();
        sem_leaf_status = sem_leaf.status();
        #4;
        mbx.put(3);
        sem.put(1);
      end
    join
  endtask

  initial begin
    mbx = new();
    sem = new(0);

    outer_frame();

    chk("nested mailbox leaf reported WAITING", mbx_leaf_status, WAITING);
    chk("nested semaphore leaf reported WAITING", sem_leaf_status, WAITING);

    chk("mailbox leaf resumed exactly once", mbx_leaf_runs, 1);
    chk("semaphore leaf resumed exactly once", sem_leaf_runs, 1);
    chk("mailbox drained", mbx.num(), 0);
    chk("message value intact", leaf_v, 3);
    chk("mailbox leaf finished", mbx_leaf.status(), FINISHED);
    chk("semaphore leaf finished", sem_leaf.status(), FINISHED);

    if (sem.try_get(1)) begin
      $display("FAILED: the woken leaf did not consume the semaphore key");
      errors++;
    end

    if (errors == 0) $display("PASSED");
    else $display("FAILED (%0d errors)", errors);
    $finish(0);
  end
endmodule
