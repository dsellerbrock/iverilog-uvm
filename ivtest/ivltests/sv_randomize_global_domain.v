// IEEE 1800-2017 18.5.9 / IEEE 1800-2023 18.5.8.
class global_leaf;
  rand bit [2:0] value;
  constraint domain { value inside {[2:3]}; }
endclass
class global_root;
  rand global_leaf children[];
  int target_base = 2;
  function new();
    children = new[2];
    foreach (children[i]) children[i] = new;
  endfunction
  constraint parent_relation {
    foreach (children[i]) children[i].value == i + target_base;
  }
endclass
module main;
  global_root root = new;
  global_leaf saved_right;
  initial begin
    root.srandom(17);
    repeat (20) begin
      if (!root.randomize()) $fatal(1, "jointly satisfiable object graph rejected");
      if (root.children[0].value != 2 || root.children[1].value != 3)
        $fatal(1, "parent and child constraints not simultaneously satisfied");
    end
    root.target_base = 4;
    if (root.randomize()) $fatal(1, "parent solve discarded child constraints");
    if (root.children[0].value != 2 || root.children[1].value != 3)
      $fatal(1, "joint failure changed child values");
    root.target_base = 2;
    saved_right = root.children[1];
    root.children[1] = root.children[0];
    if (root.randomize()) $fatal(1, "one aliased variable got two solutions");
    if (root.children[0].value != 2) $fatal(1, "alias failure changed state");
    root.children[1] = saved_right;
    root.children[0].rand_mode(0);
    root.target_base = 3;
    if (root.randomize()) $fatal(1, "disabled child handle was not held as state");
    if (root.children[0].value != 2 || root.children[1].value != 3)
      $fatal(1, "failed solve with state child changed values");
    $display("PASSED");
  end
endmodule
