class conditional_randc_leaf;
  randc bit cycle;
  rand bit gate, value;
  int posts;
  constraint relation_c {
    solve gate before value;
    gate == cycle;
  }
  constraint weighted_c {
    if (gate) value dist {0 := 1, 1 := 3};
  }
  function void disable_weighted(); weighted_c.constraint_mode(0); endfunction
  function void post_randomize(); posts++; endfunction
endclass

class conditional_randc_root;
  rand conditional_randc_leaf child;
  int posts;
  function new(); child = new; endfunction
  function void post_randomize(); posts++; endfunction
endclass

module sv_joint_ordered_guard_randc_reject;
  conditional_randc_root trial, control;
  string root_rng, child_rng;
  initial begin
    trial = new;
    control = new;
    trial.srandom(32'h52414e44);
    trial.child.srandom(32'h52414e43);
    control.srandom(32'h52414e44);
    control.child.srandom(32'h52414e43);
    trial.child.cycle = 1;
    trial.child.gate = 1;
    trial.child.value = 1;
    root_rng = trial.get_randstate();
    child_rng = trial.child.get_randstate();
    if (trial.randomize())
      $fatal(1, "conditional randc unexpectedly sampled");
    if (trial.child.cycle != 1 || trial.child.gate != 1 ||
        trial.child.value != 1 || trial.posts != 0 || trial.child.posts != 0 ||
        trial.get_randstate() != root_rng ||
        trial.child.get_randstate() != child_rng)
      $fatal(1, "conditional randc rejection changed transaction");
    trial.child.disable_weighted();
    control.child.disable_weighted();
    repeat (2) begin
      if (!trial.randomize() || !control.randomize() ||
          trial.child.cycle != control.child.cycle ||
          trial.child.gate != control.child.gate ||
          trial.child.value != control.child.value)
        $fatal(1, "conditional randc rejection consumed cycle or RNG");
    end
    if (trial.posts != 2 || trial.child.posts != 2)
      $fatal(1, "conditional randc callbacks");
    $display("PASSED");
  end
endmodule
