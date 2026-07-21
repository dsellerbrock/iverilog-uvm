// Per-instance class event properties (IEEE 1800-2017 15.5).
//
// A non-static `event` property of a class is per-instance: each object
// owns its own runtime event. Triggering one object's event (`->obj.ev`)
// must wake only waiters on that object's event (`@(obj.ev)`), never
// waiters on a different instance. This test exercises the full matrix:
//   - multiple instances (no cross-wake),
//   - multiple waiters on one instance,
//   - nonblocking trigger (`->>`),
//   - a bare member trigger/wait inside a method (this.ev),
//   - an associative-array-of-objects element (the UVM objection shape).
//
// Prints PASSED only if every sub-check holds.

module sv_class_event_per_instance;

  class box;
    event ev;
    // Bare member forms: `->ev` / `@ ev` inside a method denote this.ev.
    task automatic do_trig(); -> ev; endtask
    task automatic do_wait(); @ ev; endtask
  endclass

  int errors = 0;

  // 1. Multiple instances + multiple waiters + no cross-wake.
  task automatic test_multi();
    box a, b;
    int a_woke, b_woke;
    a = new; b = new;
    a_woke = 0; b_woke = 0;
    fork
      begin @(a.ev); a_woke++; end
      begin @(a.ev); a_woke++; end   // two waiters on a
      begin @(b.ev); b_woke++; end   // must NOT wake
    join_none
    #5 -> a.ev;
    #5;
    if (a_woke != 2) begin $display("FAIL multi: a_woke=%0d (want 2)", a_woke); errors++; end
    if (b_woke != 0) begin $display("FAIL multi: b_woke=%0d (want 0)", b_woke); errors++; end
  endtask

  // 2. Nonblocking trigger.
  task automatic test_nb();
    box a;
    bit woke;
    a = new; woke = 0;
    fork begin @(a.ev); woke = 1; end join_none
    #1 ->> a.ev;
    #2;
    if (!woke) begin $display("FAIL nb-trigger"); errors++; end
  endtask

  // 3. Bare member trig/wait inside methods (this.ev), two instances.
  task automatic test_method();
    box a, b;
    bit a_woke, b_woke;
    a = new; b = new; a_woke = 0; b_woke = 0;
    fork
      begin a.do_wait(); a_woke = 1; end
      begin b.do_wait(); b_woke = 1; end
    join_none
    #5 b.do_trig();
    #5;
    if (a_woke) begin $display("FAIL method: a woke on b trigger"); errors++; end
    if (!b_woke) begin $display("FAIL method: b did not wake"); errors++; end
  endtask

  // 4. Associative array of event-holding objects (UVM objection shape).
  task automatic test_assoc();
    box m_events [int];
    bit k1_woke, k2_woke;
    m_events[1] = new; m_events[2] = new;
    k1_woke = 0; k2_woke = 0;
    fork
      begin @(m_events[1].ev); k1_woke = 1; end
      begin @(m_events[2].ev); k2_woke = 1; end
    join_none
    #5 -> m_events[2].ev;
    #5;
    if (k1_woke) begin $display("FAIL assoc: k1 woke on k2 trigger"); errors++; end
    if (!k2_woke) begin $display("FAIL assoc: k2 did not wake"); errors++; end
  endtask

  initial begin
    test_multi();
    test_nb();
    test_method();
    test_assoc();
    if (errors == 0)
      $display("PASSED");
    else
      $display("FAILED (%0d errors)", errors);
    $finish(0);
  end

endmodule
