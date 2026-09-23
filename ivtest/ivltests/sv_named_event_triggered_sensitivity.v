`timescale 1ns/1ps
module sv_named_event_triggered_sensitivity;
  event e;
  int wakes = 0;
  bit same_slot_wait_rearmed = 0;
  bit next_slot_wait_rearmed = 0;
  bit nba_reset_wait_rearmed = 0;
  bit nba_rise_wait_rearmed = 0;
  bit finished = 0;
  int ordinary_wakes = 0;
  bit wait_saw_trigger = 0;
  bit cancelled_woke = 0;

  initial forever begin
    @(e);
    ordinary_wakes++;
  end

  initial begin
    wait (e.triggered);
    if ($time != 1 || !e.triggered)
      $fatal(1, "wait(e.triggered) changed behavior");
    wait_saw_trigger = 1;
  end

  initial begin
    fork : cancelled_property_wait
      begin
        @(e.triggered);
        cancelled_woke = 1;
      end
    join_none
    #0 disable cancelled_property_wait;
  end

  initial begin
    // First trigger changes e.triggered from 0 to 1.
    @(e.triggered);
    wakes++;
    if ($time != 1 || wakes != 1 || !e.triggered)
      $fatal(1, "first rise: t=%0t wakes=%0d value=%0b", $time, wakes, e.triggered);

    // A second trigger in this slot leaves the property at 1, so this wait
    // must remain armed until the time-slot reset changes it to 0.
    same_slot_wait_rearmed = 1;
    @(e.triggered);
    wakes++;
    if ($time != 2 || wakes != 2 || e.triggered)
      $fatal(1, "slot reset: t=%0t wakes=%0d value=%0b", $time, wakes, e.triggered);

    // The producer waits for this handshake and a #0 before triggering at t=2.
    next_slot_wait_rearmed = 1;
    @(e.triggered);
    wakes++;
    if ($time != 2 || wakes != 3 || !e.triggered)
      $fatal(1, "next-slot rise: t=%0t wakes=%0d value=%0b", $time, wakes, e.triggered);

    // At t=3 the property resets to 0; ->>e rises in the t=4 NBA region.
    nba_reset_wait_rearmed = 1;
    @(e.triggered);
    wakes++;
    if ($time != 3 || wakes != 4 || e.triggered)
      $fatal(1, "NBA-slot reset: t=%0t wakes=%0d value=%0b", $time, wakes, e.triggered);

    nba_rise_wait_rearmed = 1;
    @(e.triggered);
    wakes++;
    if ($time != 4 || wakes != 5 || !e.triggered)
      $fatal(1, "NBA rise: t=%0t wakes=%0d value=%0b", $time, wakes, e.triggered);

    finished = 1;
    $display("PASS @(e.triggered): 0->1, same-slot stable, 1->0, next-slot 0->1, NBA 1->0->1");
  end

  initial begin
    #1 -> e;
    wait (same_slot_wait_rearmed);
    #0 -> e;
    #1;
    wait (next_slot_wait_rearmed);
    #0 -> e;
    #1;
    wait (nba_reset_wait_rearmed);
    wait (nba_rise_wait_rearmed);
    #1 ->> e;
  end

  initial begin
    #6;
    if (!finished || wakes != 5 || ordinary_wakes != 4
        || !wait_saw_trigger || cancelled_woke)
      $fatal(1, "watchdog: finished=%0b wakes=%0d ordinary=%0d wait=%0b cancelled=%0b",
             finished, wakes, ordinary_wakes, wait_saw_trigger, cancelled_woke);
  end
endmodule
