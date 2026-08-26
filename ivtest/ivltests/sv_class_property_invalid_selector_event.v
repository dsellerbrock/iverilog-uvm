// Invalid/X selectors must park on an inactive, retained, cancellable waiter;
// they must never become a wildcard that wakes on an unrelated valid element.
class invalid_selector_state;
  bit [1:0] packed_value;
  bit unpacked_value [2];
  int wake_count;

  task watch_packed(input integer index);
    @(packed_value[index]);
    wake_count++;
  endtask

  task watch_negative_unpacked;
    @(unpacked_value[-1]);
    wake_count++;
  endtask
endclass

module sv_class_property_invalid_selector_event;
  invalid_selector_state state;
  integer unknown_index;

  initial begin
    state = new;
    state.packed_value = '0;
    state.unpacked_value[0] = 0;
    state.unpacked_value[1] = 0;
    unknown_index = 'x;

    fork : invalid_waiters
      state.watch_packed(-1);
      state.watch_packed(unknown_index);
      state.watch_negative_unpacked();
    join_none

    #1;
    state.packed_value[0] = 1;
    state.unpacked_value[0] = 1;
    #1;
    if (state.wake_count != 0)
      $fatal(1, "invalid selector became a wildcard (%0d wakes)",
             state.wake_count);

    disable invalid_waiters;
    state.packed_value[1] = 1;
    state.unpacked_value[1] = 1;
    #1;
    if (state.wake_count != 0)
      $fatal(1, "cancelled invalid waiter resumed");

    $display("PASSED");
  end
endmodule
