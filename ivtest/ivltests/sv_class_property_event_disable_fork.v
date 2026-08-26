// A thread killed while blocked on a class-property event must be unlinked
// before the object is mutated. The mutation must not wake or access the dead
// thread.
class class_property_disable_event_state;
  bit watched;
  bit unrelated;
  int wake_count;

  task watch_once;
    @(watched);
    wake_count++;
  endtask
endclass

module sv_class_property_event_disable_fork;
  class_property_disable_event_state state;

  initial begin
    state = new;

    fork
      state.watch_once();
    join_none

    #1;
    disable fork;

    state.unrelated = 1'b1;
    state.watched = 1'b1;
    #1;
    if (state.wake_count != 0) begin
      $fatal(1, "disabled property-event waiter woke");
    end

    $display("PASSED");
  end
endmodule
