// IEEE 1800-2017 15.3.3: a process blocked in semaphore.get() and then killed
// by `disable fork' must be removed from the semaphore's wait queue.
//
// The runtime decremented the key count BEFORE it had established that the
// waiter was still alive, so an obsolete record silently swallowed a key: a
// later put() handed its key to a dead thread and a live try_get() then
// failed. The count is now taken only after the waiter's registration is
// successfully claimed.
module sv_semaphore_kill_blocked_get;

  semaphore sem;
  int errors = 0;
  int killed_resumed = 0;

  task automatic chk(string what, int actual, int wanted);
    if (actual !== wanted) begin
      $display("FAILED %0s: got %0d exp %0d", what, actual, wanted);
      errors++;
    end
  endtask

  initial begin
    sem = new(0);                 // no keys

    fork : iso_fork
      begin
        fork
          begin
            sem.get(1);           // parks: no key available
            killed_resumed = 1;   // must never execute
          end
          #10;
        join_any
        disable fork;             // kills the branch parked in get()
      end
    join

    sem.put(1);                   // supply a key
    #10;

    chk("killed sem.get branch stayed dead", killed_resumed, 0);

    // The canceled waiter must not have consumed the key.
    if (!sem.try_get(1)) begin
      $display("FAILED: canceled waiter consumed the key");
      errors++;
    end
    // ...and there was only ever one key.
    if (sem.try_get(1)) begin
      $display("FAILED: semaphore handed out the same key twice");
      errors++;
    end

    if (errors == 0) $display("PASSED");
    else $display("FAILED (%0d errors)", errors);
    $finish(0);
  end
endmodule
