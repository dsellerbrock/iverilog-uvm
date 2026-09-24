class selfproof_guard_leaf;
  rand bit peer;
  int posts;
  function void post_randomize(); posts++; endfunction
endclass

class selfproof_guard_root;
  rand selfproof_guard_leaf child;
  rand bit gate, value, weight;
  int posts;
  function new(); child = new; gate = 1; value = 0; weight = 0; child.peer = 1; endfunction
  function void post_randomize(); posts++; endfunction
  constraint c {
    value == 0;
    child.peer == value;
    if (gate) value dist {0 := weight, 1 := 1};
  }
endclass

module sv_joint_proven_guard_selfproof;
  selfproof_guard_root root;
  string root_rng, child_rng;
  initial begin
    root = new;
    root.srandom(32'h53454c46);
    root.child.srandom(32'h50524f46);
    root_rng = root.get_randstate();
    child_rng = root.child.get_randstate();
    if (root.randomize())
      $fatal(1, "a non-ground weight proved its own guard false");
    if (root.gate != 1 || root.value != 0 || root.weight != 0 ||
        root.child.peer != 1 || root.posts != 0 || root.child.posts != 0)
      $fatal(1, "rejected self-proof changed values or ran post_randomize");
    if (root.get_randstate() != root_rng ||
        root.child.get_randstate() != child_rng)
      $fatal(1, "rejected self-proof changed RNG state");
    $display("PASSED");
    $finish(0);
  end
endmodule
