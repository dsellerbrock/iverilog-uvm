// IEEE 1800-2017 15.4.2: a process blocked in mailbox.get() and then killed
// by `disable fork' must be removed from the mailbox's wait queue.
//
// The runtime wait queue held a raw vthread pointer with no unlink path. The
// standard "race a blocking get against reset, then disable fork" pattern
// (OpenTitan's alert_receiver_driver does exactly this) left the queue naming
// a thread that had already been reaped and freed. The next put() walked that
// obsolete record: it consumed the message, pushed the item onto a freed
// thread's object stack, and scheduled freed storage -- tripping
// vthread_mark_scheduled's assert(is_scheduled == 0).
//
// The message must therefore survive the put, and the killed branch must
// never resume.
module sv_mailbox_kill_blocked_get;

  localparam int FINISHED = 0, RUNNING = 1, WAITING = 2, SUSPENDED = 3, KILLED = 4;

  mailbox #(int) mbx;
  process doomed;
  int errors = 0;
  int killed_resumed = 0;
  int got;

  task automatic chk(string what, int actual, int wanted);
    if (actual !== wanted) begin
      $display("FAILED %0s: got %0d exp %0d", what, actual, wanted);
      errors++;
    end
  endtask

  initial begin
    mbx = new();

    fork : iso_fork
      begin
        fork
          begin
            automatic int v;
            mbx.get(v);           // parks: the mailbox is empty
            killed_resumed = 1;   // must never execute
          end
          #10;                    // the sibling wins the join_any
        join_any
        disable fork;             // kills the branch parked in get()
      end
    join

    // A later put must not be consumed by the obsolete waiter.
    mbx.put(7);
    #10;                          // a resurrected branch would have run by now

    chk("killed get branch stayed dead", killed_resumed, 0);
    chk("message survived in the mailbox", mbx.num(), 1);

    if (!mbx.try_get(got)) begin
      $display("FAILED: try_get found no message");
      errors++;
    end else begin
      chk("message value intact", got, 7);
    end
    chk("mailbox drained", mbx.num(), 0);

    // Same cancellation, reached through a suspended process: kill() on a
    // process that is BOTH suspended and parked in get() must still unlink it
    // from the wait queue, so a later put keeps its message.
    begin
      automatic int susp_killed_resumed = 0;
      automatic int susp_v = 0;
      fork
        begin
          doomed = process::self();
          mbx.get(susp_v);
          susp_killed_resumed = 1;   // must never execute
        end
      join_none
      #1;
      doomed.suspend();
      #1;
      doomed.kill();
      #1;
      chk("killed suspended waiter reports KILLED", doomed.status(), KILLED);

      mbx.put(8);
      #10;
      chk("killed suspended waiter stayed dead", susp_killed_resumed, 0);
      chk("its message survived", mbx.num(), 1);
      if (!mbx.try_get(got)) begin
        $display("FAILED: try_get found no message after suspended kill");
        errors++;
      end else begin
        chk("surviving message value", got, 8);
      end
    end

    if (errors == 0) $display("PASSED");
    else $display("FAILED (%0d errors)", errors);
    $finish(0);
  end
endmodule
