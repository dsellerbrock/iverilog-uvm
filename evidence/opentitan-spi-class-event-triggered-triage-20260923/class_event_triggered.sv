class event_box;
  event ev;
endclass

module class_event_triggered;
  event_box a;
  event_box b;
  bit waiter_woke;

  initial begin
    a = new;
    b = new;
    waiter_woke = 0;

    fork
      begin
        wait (a.ev.triggered);
        waiter_woke = 1;
      end
    join_none

    #1;
    -> a.ev;

    // The event's .triggered value is true in the time slot where it fires.
    if (!a.ev.triggered) $fatal(1, "a.ev.triggered was not true in firing time slot");
    if (b.ev.triggered)  $fatal(1, "b.ev.triggered leaked from a.ev");
    #0;
    if (!waiter_woke)    $fatal(1, "wait(a.ev.triggered) did not wake in firing time slot");

    #1;
    if (a.ev.triggered)  $fatal(1, "a.ev.triggered remained true after firing time slot");
    $display("CLASS_EVENT_TRIGGERED_PASS");
    $finish;
  end
endmodule
