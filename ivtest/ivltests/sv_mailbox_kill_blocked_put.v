// IEEE 1800-2017 15.4.1: a process blocked in a bounded mailbox.put() and
// then killed by `disable fork' must be removed from the put wait queue.
//
// A bounded put parks with its message stored in the waiter record. When
// space later opened up, the runtime inserted that stored item and scheduled
// the waiter -- with no check that the waiter was still alive. A killed
// putter therefore delivered a message its process never actually handed
// over, and scheduled freed storage on the way out.
//
// Draining the original item must leave the mailbox EMPTY.
module sv_mailbox_kill_blocked_put;

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
    mbx = new(1);                 // bound of one
    mbx.put(1);                   // the mailbox is now full
    chk("mailbox is full", mbx.num(), 1);

    fork : iso_fork
      begin
        fork
          begin
            mbx.put(2);           // parks: no space
            killed_resumed = 1;   // must never execute
          end
          #10;
        join_any
        disable fork;             // kills the branch parked in put()
      end
    join

    // Removing the original item frees space. The canceled put must not
    // take it.
    if (!mbx.try_get(got)) begin
      $display("FAILED: try_get found no message");
      errors++;
    end else begin
      chk("original message intact", got, 1);
    end
    #10;

    chk("killed put branch stayed dead", killed_resumed, 0);
    chk("mailbox became empty", mbx.num(), 0);

    if (mbx.try_get(got)) begin
      $display("FAILED: canceled put inserted its item (%0d)", got);
      errors++;
    end

    if (errors == 0) $display("PASSED");
    else $display("FAILED (%0d errors)", errors);
    $finish(0);
  end
endmodule
