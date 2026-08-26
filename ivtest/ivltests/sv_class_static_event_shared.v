// IEEE 1800-2017 8.9: a static class property is shared by all objects of
// that class, while an ordinary property is allocated separately in each
// object. Named-event identity must follow the same rule.
module sv_class_static_event_shared;
  class event_box;
    static event shared_ev;
    event object_ev;

    int shared_wakes;
    int object_wakes;

    task wait_shared;
      @shared_ev;
      shared_wakes++;
    endtask

    task trigger_shared;
      ->shared_ev;
    endtask

    task wait_object;
      @object_ev;
      object_wakes++;
    endtask

    task trigger_object;
      ->object_ev;
    endtask
  endclass

  event_box a;
  event_box b;
  int errors;

  initial begin
    a = new;
    b = new;

    // The waiter enters through object a and the trigger through object b.
    // Both method calls must address the one shared static event identity.
    fork
      a.wait_shared();
    join_none
    #1 b.trigger_shared();
    #1;
    if (a.shared_wakes != 1) begin
      $display("FAILED: static event was not shared across objects");
      errors++;
    end

    // The unqualified event remains per-object. Triggering b must not wake a.
    fork
      a.wait_object();
      b.wait_object();
    join_none
    #1 b.trigger_object();
    #1;
    if (a.object_wakes != 0 || b.object_wakes != 1) begin
      $display("FAILED: ordinary event lost per-object identity, a=%0d b=%0d",
               a.object_wakes, b.object_wakes);
      errors++;
    end

    if (errors == 0)
      $display("PASSED");
    $finish(errors != 0);
  end
endmodule
