class unconstrained_dynamic_item;
  rand int queue_values[$];
  rand int dynamic_values[];
endclass

class sized_queue_item;
  rand int values[$];
  constraint fixed_size { values.size() == 3; }
endclass

module test;
  unconstrained_dynamic_item item;
  sized_queue_item sized;
  initial begin
    item = new;
    sized = new;

    item.queue_values = '{30, 10, 20};
    item.dynamic_values = new[3];
    item.dynamic_values = '{30, 10, 20};
    sized.values = '{30, 10, 20};

    // An inactive element remains state while the other queue elements
    // are still randomized.
    item.queue_values[1].rand_mode(0);
    if (!item.randomize() || !sized.randomize())
      $fatal(1, "container randomize failed");

    if (item.queue_values.size() != 3 || sized.values.size() != 3)
      $fatal(1, "unconstrained/constrained queue size changed");
    if (item.queue_values[1] != 10)
      $fatal(1, "disabled queue element changed");
    if (item.queue_values[0] == 30 && item.queue_values[2] == 20)
      $fatal(1, "unconstrained queue elements were not randomized");
    if (item.dynamic_values[0] == 30
        && item.dynamic_values[1] == 10
        && item.dynamic_values[2] == 20)
      $fatal(1, "unconstrained dynamic-array elements were not randomized");
    if (sized.values[0] == 30 && sized.values[1] == 10
        && sized.values[2] == 20)
      $fatal(1, "queue named only by size() was not randomized");

    $display("PASS");
  end
endmodule
