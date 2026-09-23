// IEEE 1800-2017/2023 15.5.3 class-event triggered property.
class triggered_box;
  event ev;
endclass

class triggered_property_box;
  logic [3:0] triggered;
endclass

module sv_class_event_triggered;
  triggered_box a, b, c, d, e, f, g, h, x, y, null_box;
  triggered_property_box ordinary;
  logic [3:0] packed_read;
  bit direct_woke, b_woke, a_woke, both_woke, rebind_woke;
  int both_count, cycles;

  initial begin
    a = new; b = new; c = new; d = new; e = new;
    f = new; g = new; h = new; x = new; y = new;
    null_box = null;
    ordinary = new;

    if ($bits(a.ev.triggered) != 1)
      $fatal(1, "class event triggered width was not one");
    if ($bits(ordinary.triggered) != 4)
      $fatal(1, "ordinary class property named triggered lost its width");
    packed_read = {3'b101, a.ev.triggered};
    if (packed_read !== 4'b1010)
      $fatal(1, "false triggered packed width/value");

    if (null_box.ev.triggered)
      $fatal(1, "null class event triggered was not false");

    // A trigger before the wait in the same time step must already read true.
    -> a.ev;
    if (!a.ev.triggered || b.ev.triggered)
      $fatal(1, "triggered read or per-instance isolation failed");
    packed_read = {3'b101, a.ev.triggered};
    if (packed_read !== 4'b1011)
      $fatal(1, "true triggered packed width/value");
    wait (a.ev.triggered);

    fork
      begin wait (b.ev.triggered); direct_woke = 1; end
      begin wait (c.ev.triggered || d.ev.triggered); b_woke = 1; end
      begin wait (e.ev.triggered || f.ev.triggered); a_woke = 1; end
      begin wait (g.ev.triggered || h.ev.triggered); both_woke = 1; both_count++; end
      begin wait (null_box.ev.triggered); rebind_woke = 1; end
      begin
        repeat (2) begin
          wait (x.ev.triggered || y.ev.triggered);
          cycles++;
          #1;
        end
      end
    join_none

    #1 begin -> b.ev; -> d.ev; null_box = new; end
    #0;
    if (!direct_woke || !b_woke || a_woke || both_woke || rebind_woke)
      $fatal(1, "direct or b-only compound wait failed");
    if (c.ev.triggered || e.ev.triggered || f.ev.triggered)
      $fatal(1, "class event trigger leaked between instances");

    #1 begin -> e.ev; -> null_box.ev; end // left side and rebound event
    #0;
    if (!a_woke || both_woke || !rebind_woke)
      $fatal(1, "a-only compound wait or null-handle rebind failed");

    #1 begin -> g.ev; -> h.ev; end // both branches fire in one time step
    #0;
    if (!both_woke || both_count != 1)
      $fatal(1, "simultaneous compound wait failed");

    #1 -> x.ev;
    #1 -> y.ev;
    #0;
    if (cycles != 2)
      $fatal(1, "compound wait did not rearm cleanly: cycles=%0d", cycles);

    #1;
    if (a.ev.triggered || b.ev.triggered || e.ev.triggered
        || g.ev.triggered || h.ev.triggered || x.ev.triggered || y.ev.triggered)
      $fatal(1, "triggered remained true after its time step");

    $display("CLASS_EVENT_TRIGGERED_PASS");
  end
endmodule
