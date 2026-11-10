// `x == y` with conflicting guarded dist weights on x and y. Nonzero
// weights "do not change the solution space and, therefore, cannot cause
// the solver to fail" (IEEE 1800-2023 18.5.3; 1800-2017 18.5.4), so every
// randomize() succeeds and satisfies the hard constraint; the solve-before
// order still draws gate first (18.5.9).
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
  int gates[2];
  initial begin
    root = new;
    root.srandom(32'h47f1de);
    root.child.srandom(32'h47f1df);
    for (int i = 0; i < 200; i++) begin
      if (!root.randomize()) $fatal(1, "randomize() failed at draw %0d", i);
      if (root.child.x != root.child.y)
        $fatal(1, "x == y violated at draw %0d", i);
      gates[root.child.gate]++;
    end
    if (root.posts != 200 || root.child.posts != 200)
      $fatal(1, "post_randomize counts %0d %0d", root.posts, root.child.posts);
    if (gates[0] == 0 || gates[1] == 0)
      $fatal(1, "gate never took both values: %0d %0d", gates[0], gates[1]);
    $display("PASSED");
  end
endmodule
