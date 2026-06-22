// Event task-ports: "task t(event e); ... @(e)" with the event passed by
// reference.  The hard case (and the one that proves this is not a
// single-call illusion) is forking the SAME automatic task twice with two
// DIFFERENT class-member events: each instance must wake only on its own
// trigger.  Shared by every OpenTitan DV scoreboard's collect_*_coverage
// tasks (e.g. aon_timer_scoreboard).
class evt_harness;
  event e1, e2;
  int n1 = 0, n2 = 0;

  // A single automatic task, invoked twice below with different events.
  task automatic collect(event sample, int which);
    forever begin
      @(sample);
      if (which == 1) n1++; else n2++;
    end
  endtask

  task automatic run();
    fork
      collect(e1, 1);
      collect(e2, 2);
    join_none
    #1 -> e1;   // wakes only the (e1,1) instance
    #1 -> e2;   // wakes only the (e2,2) instance
    #1 -> e1;
    #1 -> e1;
    #1 -> e2;
    #2;
  endtask
endclass

module event_task_port_test;
  initial begin
    evt_harness h = new();
    h.run();
    #20;
    // e1 fired 3 times, e2 fired 2 times; each formal must have routed to
    // its own actual event only.
    if (h.n1 == 3 && h.n2 == 2)
      $display("PASS n1=%0d n2=%0d", h.n1, h.n2);
    else
      $display("FAIL n1=%0d n2=%0d (expected n1=3 n2=2)", h.n1, h.n2);
    $finish;
  end
endmodule
