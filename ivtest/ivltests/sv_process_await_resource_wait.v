// IEEE 1800-2017 9.7: process::await() is a blocking resource wait and shares
// the mailbox/semaphore cancellation machinery.
//
// Two defects are pinned here:
//
//   - An awaiting thread killed while parked in await() stayed in the target
//     process's waiter set. signal_waiters_() then read `i_have_ended' off
//     that freed thread -- a use-after-free guarding a use-after-free -- and
//     could schedule it.
//
//   - status() had no idea a thread parked in a blocking mailbox or semaphore
//     operation was blocked at all, so such a process reported RUNNING
//     instead of WAITING.
module sv_process_await_resource_wait;

  localparam int FINISHED = 0, RUNNING = 1, WAITING = 2, SUSPENDED = 3, KILLED = 4;

  mailbox #(int) mbx;
  process worker, blocked_reader;

  int errors = 0;
  int await_count = 0;
  int killed_await_resumed = 0;
  int blocked_status = -1;
  int reader_v = 0;

  task automatic chk(string what, int actual, int wanted);
    if (actual !== wanted) begin
      $display("FAILED %0s: got %0d exp %0d", what, actual, wanted);
      errors++;
    end
  endtask

  initial begin
    mbx = new();

    // A worker that finishes on its own clock.
    fork begin worker = process::self(); #20; end join_none
    #1;

    // Normal completion: this await must resume exactly once.
    fork
      begin
        worker.await();
        await_count++;
      end
    join_none

    // A thread parked in mailbox.get(): its process must report WAITING.
    fork
      begin
        blocked_reader = process::self();
        mbx.get(reader_v);
      end
    join_none
    #1;
    blocked_status = blocked_reader.status();

    // An awaiting thread killed while parked inside await().
    fork : iso_fork
      begin
        fork
          begin
            worker.await();
            killed_await_resumed = 1;   // must never execute
          end
          #2;
        join_any
        disable fork;
      end
    join

    #30;                                 // the worker ends at 20 and signals

    chk("blocked mailbox reader reports WAITING", blocked_status, WAITING);
    chk("normal await resumed exactly once", await_count, 1);
    chk("killed awaiting thread stayed dead", killed_await_resumed, 0);
    chk("worker finished", worker.status(), FINISHED);

    // The still-parked reader is released cleanly afterwards.
    mbx.put(9);
    #1;
    chk("mailbox reader drained", mbx.num(), 0);
    chk("reader got the message", reader_v, 9);
    chk("reader process finished", blocked_reader.status(), FINISHED);

    if (errors == 0) $display("PASSED");
    else $display("FAILED (%0d errors)", errors);
    $finish(0);
  end
endmodule
