// IEEE 1800-2023 7.4.5 and 15.5.5: an element of an event array is an event
// and can be assigned to an event variable, which then shares the element's
// synchronization queue; reading with an invalid index gives null. The
// element is found by its declared index (#3383: a range that does not
// start at 0).
module top;
  event events[0:1];
  event ev45[4:5];
  event target, other;
  int idx = 1;
  int hits = 0;
  int errors = 0;

  task automatic expect_hits(input int want, input string what);
    if (hits !== want) begin
      $display("FAILED: %s: hits=%0d, want %0d", what, hits, want);
      errors += 1;
    end
  endtask

  initial begin
    // The variable names the queue of events[1].
    target = events[idx];
    fork
      begin @(target); hits += 1; end
      begin @(events[1]); hits += 10; end
    join_none
    #1 -> events[1];
    #1 expect_hits(11, "trigger of the element wakes both");

    // A trigger through the variable wakes a waiter on the element.
    fork
      begin @(events[1]); hits += 100; end
    join_none
    #1 -> target;
    #1 expect_hits(111, "trigger through the variable");

    // Another element is another queue.
    fork
      begin @(target); hits += 1000; end
    join_none
    #1 -> events[0];
    #1 expect_hits(111, "trigger of another element");
    -> events[1];
    #1 expect_hits(1111, "trigger of the aliased element");

    // An invalid index reads as null: a trigger has no effect.
    idx = 9;
    target = events[idx];
    fork
      begin @(events[1]); hits += 10000; end
    join_none
    #1 -> target;
    #1 expect_hits(1111, "trigger of a null event");

    // Declared bounds that do not start at 0.
    other = ev45[5];
    fork
      begin @(other); hits += 100000; end
      begin @(ev45[4]); hits += 1000000; end
    join_none
    #1 -> ev45[4];
    #1 expect_hits(1001111, "trigger of ev45[4]");
    -> ev45[5];
    #1 expect_hits(1101111, "trigger of ev45[5]");

    if (errors == 0) $display("PASSED");
    $finish;
  end
endmodule
