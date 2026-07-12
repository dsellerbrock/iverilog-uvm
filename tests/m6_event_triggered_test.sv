// M6 / G08 regression: event.triggered must be true for the remainder of
// the time slot in which the event fires (IEEE 1800-2017 15.5.3), so
// both an @(e) waiter and a wait(e.triggered) waiter observe one
// trigger, with no race.
module m6_event_triggered_test;
  event e;
  int hits = 0;

  initial begin
    fork
      begin @(e);              hits += 1; end
      begin wait (e.triggered); hits += 1; end
    join_none
    #1 ->e;
    #1;
    if (hits != 2) $display("FAIL g08a hits=%0d expected 2", hits);

    // triggered must read true LATER in the same slot even for a
    // process that starts waiting AFTER the trigger fired.
    fork
      begin #1 ->e; end
      begin #1 wait (e.triggered); hits += 10; end
    join
    if (hits != 12) $display("FAIL g08b hits=%0d expected 12", hits);

    // and must read false again in the NEXT slot.
    #1;
    fork
      begin wait (e.triggered); hits += 100; end
      begin #1; end
    join_any
    disable fork;
    if (hits == 12) $display("PASS");
    else $display("FAIL g08c hits=%0d (stale trigger leaked)", hits);
    $finish;
  end
endmodule
