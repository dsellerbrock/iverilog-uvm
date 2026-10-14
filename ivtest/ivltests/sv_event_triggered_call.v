// IEEE 1800-2017/2023 15.5.3: triggered() returns the named event's
// one-bit triggered state for the current time step.
class event_triggered_call_box;
  static event shared_ev;
  static bit shared_wait_woke;
  event ev;

  static task wait_shared();
    wait (shared_ev.triggered());
    shared_wait_woke = 1;
  endtask

  static function bit shared_triggered();
    return shared_ev.triggered();
  endfunction

  static function int shared_triggered_width();
    return $bits(shared_ev.triggered());
  endfunction

  static task fire_shared();
    -> shared_ev;
  endtask
endclass

module sv_event_triggered_call;
  event named;
  event null_named;
  event event_array[2];
  event_triggered_call_box first, second, null_box;
  bit named_wait_woke, class_wait_woke;

  initial begin
    if ($bits(named.triggered()) != 1
        || $bits(event_array[1].triggered()) != 1 || named.triggered())
      $fatal(1, "initial named-event triggered() result or width");

    if (null_named.triggered())
      $fatal(1, "triggered() on a null named event was not false");

    fork
      begin
        wait (named.triggered());
        named_wait_woke = 1;
      end
      begin -> named; end
    join
    if (!named_wait_woke || !named.triggered())
      $fatal(1, "named-event triggered() missed a same-time trigger");

    -> event_array[1];
    if (event_array[0].triggered() || !event_array[1].triggered())
      $fatal(1, "event-array triggered() did not select the matching event");

    first = new;
    second = new;
    if ($bits(first.ev.triggered()) != 1
        || event_triggered_call_box::shared_triggered_width() != 1)
      $fatal(1, "class-event triggered() result width was not one");

    fork
      begin event_triggered_call_box::wait_shared(); end
      begin event_triggered_call_box::fire_shared(); end
    join
    if (!event_triggered_call_box::shared_wait_woke
        || !event_triggered_call_box::shared_triggered())
      $fatal(1, "static class-event triggered() missed a same-time trigger");

    fork
      begin
        wait (first.ev.triggered());
        class_wait_woke = 1;
      end
      begin -> first.ev; end
    join
    if (!class_wait_woke || !first.ev.triggered() || second.ev.triggered())
      $fatal(1, "per-instance class-event triggered() missed its event");

    null_box = null;
    if (null_box.ev.triggered())
      $fatal(1, "triggered() through a null class handle was not false");

    #1;
    if (named.triggered() || event_array[1].triggered()
        || first.ev.triggered()
        || event_triggered_call_box::shared_triggered())
      $fatal(1, "triggered() state did not clear after time advanced");

    $display("PASS explicit named-event triggered() in both editions");
  end
endmodule
