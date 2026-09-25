class prefix_cap_leaf;
  rand bit [10:0] gate;
  rand bit x, y;
  int posts;
  constraint c {
    solve gate before x, y;
    if (gate[0]) {
      x dist {0 := 1, 1 := 3};
      y dist {0 := 3, 1 := 1};
    }
  }
  function void post_randomize(); posts++; endfunction
endclass

class prefix_cap_root;
  rand prefix_cap_leaf child;
  int posts;
  function new(); child = new; endfunction
  function void post_randomize(); posts++; endfunction
endclass

module sv_joint_ordered_guard_prefix_cap_reject;
  prefix_cap_root root;
  string root_rng, child_rng;
  initial begin
    root = new;
    root.child.gate = 11'h555;
    root.child.x = 1;
    root.child.y = 0;
    root.srandom(32'h43415052);
    root.child.srandom(32'h43415043);
    root_rng = root.get_randstate();
    child_rng = root.child.get_randstate();
    if (root.randomize()) $fatal(1, "oversize guard prefix sampled");
    if (root.child.gate != 11'h555 || root.child.x != 1 ||
        root.child.y != 0 || root.posts != 0 || root.child.posts != 0 ||
        root.get_randstate() != root_rng ||
        root.child.get_randstate() != child_rng)
      $fatal(1, "prefix cap rejection changed transaction");
    $display("PASSED");
  end
endmodule
