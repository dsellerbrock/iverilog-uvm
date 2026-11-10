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
  initial begin
    root = new;
    root.srandom(32'h43415052);
    root.child.srandom(32'h43415043);
    if (!root.randomize()) $fatal(1, "oversize guard prefix failed");
    if (root.posts != 1 || root.child.posts != 1)
      $fatal(1, "successful randomize omitted post_randomize");
    $display("PASSED");
  end
endmodule
