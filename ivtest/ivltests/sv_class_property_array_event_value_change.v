// An event control on one fixed-array class property element is sensitive to
// that selected value, not every element or property of the owning object.
// This mirrors OpenTitan HMAC's @(last_intr_test_wr[intr_i]) scoreboard loop.
class class_property_array_event_state;
  bit watched[2];
  bit unrelated;
  int wake_count;

  task watch_once(input int index);
    @(watched[index]);
    wake_count++;
  endtask
endclass

class class_property_array_event_leaf;
  bit done;
endclass

module sv_class_property_array_event_value_change;
  class_property_array_event_state state;
  class_property_array_event_leaf owners[2];
  int owner_wake_count;
  int owner_index;
  bit owner_wait_completed;

  initial begin
    state = new;

    fork
      state.watch_once(1);
    join_none

    #1;
    state.watched[0] = 1'b1;
    #1;
    if (state.wake_count != 0) begin
      $fatal(1, "other array element woke selected event");
    end

    state.unrelated = 1'b1;
    state.watched[1] = state.watched[1];
    #1;
    if (state.wake_count != 0) begin
      $fatal(1, "unrelated/same-value write woke selected event");
    end

    state.watched[1] = 1'b1;
    #1;
    if (state.wake_count != 1) begin
      $fatal(1, "selected value change produced %0d wakes", state.wake_count);
    end

    // A fixed unpacked array of class handles carries one root nexus per
    // word. Preserve the selected owner instead of silently loading word 0.
    owners[0] = new;
    owners[1] = new;
    fork
      begin
        @(owners[1].done);
        owner_wake_count++;
      end
    join_none
    #1;
    owners[0].done = 1'b1;
    #1;
    if (owner_wake_count != 0) begin
      $fatal(1, "unselected class-handle array word woke event");
    end
    owners[1].done = 1'b1;
    #1;
    if (owner_wake_count != 1) begin
      $fatal(1, "selected class-handle array word produced %0d wakes",
             owner_wake_count);
    end

    // A wait also observes its run-time owner index and migrates to the newly
    // selected class handle when that index changes.
    owners[0].done = 1'b0;
    owners[1].done = 1'b1;
    owner_index = 0;
    fork
      begin
        wait (owners[owner_index].done);
        owner_wait_completed = 1'b1;
      end
    join_none
    #1;
    owner_index = 1;
    #1;
    if (!owner_wait_completed) begin
      $fatal(1, "dynamic class-handle array owner did not re-arm wait");
    end

    $display("PASSED");
  end
endmodule
