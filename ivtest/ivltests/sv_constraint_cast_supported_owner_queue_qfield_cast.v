// IEEE 1800-2017 18.5.8.1 / IEEE 1800-2023 18.5.7.1.
// Positive compiler fixture: an inline constraint iterates a selected caller
// state queue. The typed cast wraps the qfield read in the foreach body.
package qfield_cast_state;
  typedef struct { logic [7:0] value; } state_value_t;
  typedef struct { state_value_t values[$]; } holder_t;
  holder_t holders[$] = '{'{'{'{8'h2a}}}};
endpackage

class cast_state_item;
  rand int value;
endclass

module supported_owner_queue_qfield_cast;
  import qfield_cast_state::*;
  cast_state_item item = new;
  int selected = 0;

  initial begin
    if (!item.randomize() with {
      foreach (holders[selected].values[i])
        value == int'(holders[selected].values[i].value);
    })
      $fatal(1, "selected queue foreach with integral qfield cast failed");
    if (item.value != 42)
      $fatal(1, "selected queue qfield cast produced %0d", item.value);
    $display("PASSED");
  end
endmodule
