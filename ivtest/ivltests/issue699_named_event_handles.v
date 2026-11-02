class static_event_handles;
  static event first, second;
endclass

module issue699_named_event_handles;
  event e1, e2, e3;
  integer old_e1_woke = 0;
  integer old_e2_woke = 0;
  integer new_e1_woke = 0;
  integer new_e2_woke = 0;
  integer rebound_e1_woke = 0;
  integer rebound_e3_woke = 0;
  integer null_trigger_woke = 0;

  task automatic check_automatic_handles;
    event a, b;
    begin
      if (a == b || a === b || !(a != b) || !(a !== b))
        $fatal(1, "automatic events do not have distinct queues");
      a = b;
      if (!(a == b) || a != b || !(a === b) || a !== b || !a)
        $fatal(1, "automatic event assignment failed");
      a = null;
      if (!(a == null) || a != null || !(a === null) || a !== null || a)
        $fatal(1, "automatic event null assignment failed");
    end
  endtask

  initial begin
    if (e1 == e2 || e1 === e2 || !(e1 != e2) || !(e1 !== e2))
      $fatal(1, "new events do not have distinct queues");
    if (!e1 || !e2 || e1 == null || e1 === null
        || !(e1 != null) || !(e1 !== null))
      $fatal(1, "new event handle has incorrect truth or null value");

    fork
      begin @e1; old_e1_woke = 1; end
      begin @e2; old_e2_woke = 1; end
    join_none
    #0;
    e1 = e2;
    if (!(e1 == e2) || e1 != e2 || !(e1 === e2) || e1 !== e2)
      $fatal(1, "event comparison failed after assignment");
    -> e2;
    #0;
    if (old_e1_woke || !old_e2_woke)
      $fatal(1, "assignment changed an already-armed event wait");

    fork
      begin @e1; new_e1_woke = 1; end
      begin @e2; new_e2_woke = 1; end
    join_none
    #0;
    -> e1;
    #0;
    if (!new_e1_woke || !new_e2_woke)
      $fatal(1, "assigned event handles did not share their queue");

    e1 = null;
    if (!(e1 == null) || e1 != null || !(e1 === null) || e1 !== null || e1)
      $fatal(1, "event null assignment failed");
    fork begin @e2; null_trigger_woke = 1; end join_none
    #0;
    -> e1;
    #0;
    if (null_trigger_woke)
      $fatal(1, "triggering a null event affected another event");

    e1 = e3;
    if (!(e1 == e3) || e1 !== e3 || e1 == null)
      $fatal(1, "event reassignment failed");
    fork
      begin @e1; rebound_e1_woke = 1; end
      begin @e3; rebound_e3_woke = 1; end
    join_none
    #0;
    -> e3;
    #0;
    if (!rebound_e1_woke || !rebound_e3_woke || old_e1_woke)
      $fatal(1, "reassigned event handles did not share only the new queue");

    check_automatic_handles();

    if (static_event_handles::first == static_event_handles::second)
      $fatal(1, "static class events do not have distinct queues");
    static_event_handles::first = static_event_handles::second;
    if (static_event_handles::first !== static_event_handles::second)
      $fatal(1, "static class event assignment failed");
    static_event_handles::first = null;
    if (static_event_handles::first != null)
      $fatal(1, "static class event null assignment failed");

    disable fork;
    $display("PASS");
  end
endmodule
