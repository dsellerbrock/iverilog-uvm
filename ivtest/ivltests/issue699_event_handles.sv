// IEEE 1800-2017/2023 15.5.5: event variables share synchronization queues
// by assignment, detach with null, and compare by queue (15.5.5.1-3).
module issue699_event_handles;
  event a, b, c, d, e1, e2, n;
  int hits_a = 0, hits_b = 0, hits_c = 0;
  bit old_waiter_woke = 0, new_waiter_woke = 0, saw_triggered = 0;
  bit ok = 1;

  task check(bit cond, string what);
    if (!cond) begin $display("FAILED: %s", what); ok = 0; end
  endtask

  initial begin
    check(a != b && !(a == b) && a !== b, "distinct events compare unequal");
    check(a != null && !(a == null), "a declared event is not null");

    a = b;
    check(a == b && a === b && !(a != b), "merged events compare equal");
    fork
      begin @a; hits_a++; end
      begin @b; hits_b++; end
    join_none
    #1 -> a;               // also triggers b
    #1 check(hits_a == 1 && hits_b == 1, "trigger through a wakes waiters on both");
    fork
      begin @a; hits_a++; end
      begin @b; hits_b++; end
    join_none
    #1 -> b;               // also triggers a
    #1 check(hits_a == 2 && hits_b == 2, "trigger through b wakes waiters on both");

    // 15.5.5.1: a process already waiting on e2 keeps e2's old queue.
    fork
      begin @e2; old_waiter_woke = 1; end
    join_none
    #1 e2 = e1;
    fork
      begin @e1; new_waiter_woke = 1; end
    join_none
    #1 -> e2;
    #1 check(new_waiter_woke && !old_waiter_woke, "existing waiter stays on its old queue");

    // a keeps b's queue when b is reassigned.
    b = c;
    check(a != b && b == c, "reassigning the queue owner");
    fork
      begin @a; hits_a++; end
      begin @c; hits_c++; end
    join_none
    #1 -> a;
    #1 check(hits_a == 3 && hits_c == 0, "a still names b's old queue");
    -> b;
    #1 check(hits_c == 1, "b now names c's queue");

    // .triggered follows the shared queue.
    d = c;
    fork
      begin #1 -> c; end
      begin #1 wait (d.triggered); saw_triggered = 1; end
    join
    check(saw_triggered, "triggered state of a merged event");

    // 15.5.5.2 / 15.5.5.3: null.
    n = null;
    check(n == null && n === null && !(n != null), "null event compares equal to null");
    if (n) check(0, "a null event is false");
    -> n;                  // no effect
    n = a;
    check(n == a && n != null, "a reclaimed variable can be assigned again");

    if (ok) $display("PASSED");
  end
endmodule
