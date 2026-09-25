class guard_coupled_leaf;
  rand bit gate, x, y;
  int posts;
  constraint c {
    solve gate before x, y;
    x == y;
    if (gate) {
      x dist {0 := 1, 1 := 3};
      y dist {0 := 3, 1 := 1};
    }
  }
  function void post_randomize(); posts++; endfunction
endclass

class guard_coupled_root;
  rand guard_coupled_leaf child;
  int posts;
  function new(); child = new; endfunction
  function void post_randomize(); posts++; endfunction
endclass

module sv_joint_ordered_guard_coupled_reject;
  guard_coupled_root root;
  string root_rng, child_rng;
  initial begin
    root = new;
    root.child.gate = 1;
    root.child.x = 1;
    root.child.y = 1;
    root.srandom(32'h47f1de);
    root.child.srandom(32'h47f1df);
    root_rng = root.get_randstate();
    child_rng = root.child.get_randstate();
    if (root.randomize()) $fatal(1, "unproved coupled weights were sampled");
    if (root.child.gate != 1 || root.child.x != 1 || root.child.y != 1 ||
        root.posts != 0 || root.child.posts != 0 ||
        root.get_randstate() != root_rng ||
        root.child.get_randstate() != child_rng)
      $fatal(1, "rejected coupled weights changed the transaction");
    $display("PASSED");
  end
endmodule
