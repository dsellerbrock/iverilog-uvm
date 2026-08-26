// IEEE 1800-2017 9.4.2.1: an event expression triggers only when its
// expression changes value. Mutating another property of the same object, or
// assigning the watched property its current value, must not wake this event
// control.
class class_property_event_state;
  bit watched;
  bit unrelated;
  int wake_count;

  task watch_once;
    @(watched);
    wake_count++;
  endtask
endclass

module sv_class_property_event_value_change;
  class_property_event_state state;
  bit root_handle_woke;

  initial begin
    state = new;

    fork
      state.watch_once();
      begin
        @(state);
        root_handle_woke = 1'b1;
      end
    join_none

    // Let the child arm its event control before performing either write.
    #1;
    state.unrelated = 1'b1;
    #1;
    if (state.wake_count != 0) begin
      $fatal(1, "unrelated property write woke @(watched)");
    end

    state.watched = state.watched;
    #1;
    if (state.wake_count != 0) begin
      $fatal(1, "same-value property write woke @(watched)");
    end

    state.watched = 1'b1;
    #1;
    if (state.wake_count != 1) begin
      $fatal(1, "value change produced %0d wakes", state.wake_count);
    end

    if (root_handle_woke) begin
      $fatal(1, "property alias delivery looked like a root handle change");
    end

    begin
      class_property_event_state replacement;
      replacement = new;
      state = replacement;
      #1;
      if (!root_handle_woke) begin
        $fatal(1, "class root handle replacement did not trigger event");
      end
    end

    $display("PASSED");
  end
endmodule
