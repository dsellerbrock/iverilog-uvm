// IEEE 1800-2017 15.4.3: a process blocked in mailbox.peek() and then killed
// by `disable fork' must be removed from the mailbox's wait queue.
//
// peek() shares the get wait queue, so the same obsolete-record defect
// applied: the next put() reached into the killed thread's object stack to
// hand over the peeked item and then scheduled it. Unlike get(), a peek
// waiter does not consume the message, so the visible damage was the freed
// stack write and the bogus schedule -- both of which this test pins by
// requiring the message to stay put and the branch to stay dead.
module sv_mailbox_kill_blocked_peek;

  mailbox #(int) mbx;
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
            mbx.peek(v);          // parks: the mailbox is empty
            killed_resumed = 1;   // must never execute
          end
          #10;
        join_any
        disable fork;             // kills the branch parked in peek()
      end
    join

    mbx.put(7);
    #10;

    chk("killed peek branch stayed dead", killed_resumed, 0);
    chk("message survived in the mailbox", mbx.num(), 1);

    if (!mbx.try_get(got)) begin
      $display("FAILED: try_get found no message");
      errors++;
    end else begin
      chk("message value intact", got, 7);
    end
    chk("mailbox drained", mbx.num(), 0);

    if (errors == 0) $display("PASSED");
    else $display("FAILED (%0d errors)", errors);
    $finish(0);
  end
endmodule
