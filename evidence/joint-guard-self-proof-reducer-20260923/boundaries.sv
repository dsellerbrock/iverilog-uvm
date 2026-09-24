class boundary_leaf;
  rand bit peer;
endclass

class false_guard_item;
  rand boundary_leaf child;
  rand bit gate, value, item;
  function new(); child = new; endfunction
  constraint c {
    gate == 0;
    value == 1;
    child.peer == value;
    if (gate) value dist {item := 1};
  }
endclass

class inactive_subject_weight;
  rand boundary_leaf child;
  rand bit value, weight;
  function new(); child = new; value = 1; weight = 0; endfunction
  constraint c {
    child.peer == value;
    value dist {0 := weight, 1 := 1};
  }
endclass

module top;
  false_guard_item known_false = new;
  inactive_subject_weight inactive_subject = new;
  initial begin
    if (!known_false.randomize() || known_false.gate != 0 ||
        known_false.value != 1 || known_false.child.peer != 1)
      $fatal(1, "independently false guarded non-ground item was rejected");
    inactive_subject.value.rand_mode(0);
    if (inactive_subject.randomize())
      $fatal(1, "inactive subject hid unsupported weight");
    $display("EXPECTED_BOUNDARIES");
    $finish(0);
  end
endmodule
