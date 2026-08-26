// An event control on a runtime-selected packed bit of a class property is
// sensitive only to that bit's value. This is the exact shape used by
// OpenTitan HMAC's @(last_intr_test_wr[intr_i]) scoreboard loop.
class class_property_packed_event_state;
  bit [1:0] watched;
  bit unrelated;
  int wake_count;

  task watch_once(input int index);
    @(watched[index]);
    wake_count++;
  endtask
endclass

module sv_class_property_packed_bit_event_value_change;
  class_property_packed_event_state state;

  initial begin
    state = new;

    fork
      state.watch_once(1);
    join_none

    #1;
    state.watched[0] = 1'b1;
    #1;
    if (state.wake_count != 0) begin
      $fatal(1, "other packed bit woke selected event");
    end

    state.unrelated = 1'b1;
    state.watched[1] = state.watched[1];
    #1;
    if (state.wake_count != 0) begin
      $fatal(1, "unrelated/same-value write woke selected packed event");
    end

    state.watched[1] = 1'b1;
    #1;
    if (state.wake_count != 1) begin
      $fatal(1, "selected packed value change produced %0d wakes",
             state.wake_count);
    end

    $display("PASSED");
  end
endmodule
