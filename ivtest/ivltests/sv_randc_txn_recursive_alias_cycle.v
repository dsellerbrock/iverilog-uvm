class recursive_walk_leaf;
  randc bit [1:0] value;
endclass

class recursive_alias_parent;
  rand recursive_walk_leaf left;
  rand recursive_walk_leaf right;

  function new;
    recursive_walk_leaf shared;
    shared = new;
    left = shared;
    right = shared;
  endfunction
endclass

class recursive_cycle_node;
  randc bit [1:0] value;
  rand recursive_cycle_node next;

  function new;
    next = this;
  endfunction
endclass

class recursive_container_parent;
  rand recursive_walk_leaf dynamic_values[];
  rand recursive_walk_leaf queue_values[$];
  rand recursive_walk_leaf assoc_values[string];

  function new;
    recursive_walk_leaf item;
    dynamic_values = new[1];
    dynamic_values[0] = new;
    item = new;
    queue_values.push_back(item);
    assoc_values["item"] = new;
  endfunction
endclass

module test;
  initial begin
    recursive_alias_parent aliases;
    recursive_walk_leaf control;
    recursive_cycle_node cycle;
    recursive_container_parent containers;
    string dynamic_before;
    string queue_before;
    string assoc_before;

    aliases = new;
    control = new;
    aliases.left.srandom(32'h2468_ace0);
    control.srandom(32'h2468_ace0);
    if (aliases.randomize() !== 1 || control.randomize() !== 1)
      $fatal(1, "alias/control randomize failed");
    if (aliases.left != aliases.right)
      $fatal(1, "randomize changed aliased child handles");
    if (aliases.left.value !== control.value)
      $fatal(1, "aliased child was randomized more than once");

    // A self edge is one already-visited object, not permission to begin a
    // nested transaction on the same receiver or recurse forever.
    cycle = new;
    cycle.srandom(32'h55aa_00ff);
    if (cycle.randomize() with { value inside {[2'd0:2'd3]}; } !== 1)
      $fatal(1, "self-referential randomize-with failed");
    if (cycle.next != cycle)
      $fatal(1, "self-referential handle identity changed");

    // Dynamic arrays, queues, and associative arrays of class handles all
    // participate in the same recursive graph traversal.
    containers = new;
    containers.dynamic_values[0].srandom(32'h0102_0304);
    containers.queue_values[0].srandom(32'h1112_1314);
    containers.assoc_values["item"].srandom(32'h2122_2324);
    dynamic_before = containers.dynamic_values[0].get_randstate();
    queue_before = containers.queue_values[0].get_randstate();
    assoc_before = containers.assoc_values["item"].get_randstate();
    if (containers.randomize() !== 1)
      $fatal(1, "container graph randomize failed");
    if (containers.dynamic_values[0].get_randstate() == dynamic_before)
      $fatal(1, "dynamic-array child was not randomized");
    if (containers.queue_values[0].get_randstate() == queue_before)
      $fatal(1, "queue child was not randomized");
    if (containers.assoc_values["item"].get_randstate() == assoc_before)
      $fatal(1, "associative-array child was not randomized");

    $display("PASSED");
  end
endmodule
