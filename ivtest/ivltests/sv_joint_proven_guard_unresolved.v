class unresolved_guard_leaf;
  rand bit gate;
  rand bit value;
  int posts;
  constraint c {if (gate) value dist {1'b0 := 1, 1'b1 := 9};}
  function void post_randomize(); posts++; endfunction
endclass

class unresolved_guard_root;
  rand unresolved_guard_leaf a, b;
  int posts;
  constraint coupled_c {a.gate == b.gate; a.value == b.value;}
  function new(); a = new; b = new; endfunction
  function void post_randomize(); posts++; endfunction
endclass

module sv_joint_proven_guard_unresolved;
  unresolved_guard_root root;
  string root_rng, a_rng, b_rng;
  initial begin
    root = new;
    root.a.gate = 1;
    root.a.value = 1;
    root.b.gate = 1;
    root.b.value = 1;
    root.srandom(32'h4a474f52);
    root.a.srandom(32'h4a474f41);
    root.b.srandom(32'h4a474f42);
    root_rng = root.get_randstate();
    a_rng = root.a.get_randstate();
    b_rng = root.b.get_randstate();
    if (root.randomize())
      $fatal(1, "unresolved random guard was sampled without a fiber proof");
    if (root.a.gate != 1 || root.a.value != 1 ||
        root.b.gate != 1 || root.b.value != 1 ||
        root.posts != 0 || root.a.posts != 0 || root.b.posts != 0)
      $fatal(1, "rejected joint solve changed values or ran post_randomize");
    if (root.get_randstate() != root_rng ||
        root.a.get_randstate() != a_rng || root.b.get_randstate() != b_rng)
      $fatal(1, "rejected joint solve changed RNG state");
    $display("PASSED");
    $finish(0);
  end
endmodule
