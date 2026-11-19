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
  function void post_randomize(); posts++; endfunction
endclass

class conditional_randc_root;
  rand conditional_randc_leaf child;
  int posts;
  function new(); child = new; endfunction
  function void post_randomize(); posts++; endfunction
endclass

module sv_joint_ordered_guard_randc_reject;
  conditional_randc_root trial;
  bit first_cycle;
  initial begin
    trial = new;
    trial.srandom(32'h52414e44);
    trial.child.srandom(32'h52414e43);
    for (int draw = 1; draw <= 4; draw++) begin
      if (!trial.randomize() || trial.child.gate != trial.child.cycle)
        $fatal(1, "conditional randc failed at draw %0d", draw);
      if (draw % 2 == 1) first_cycle = trial.child.cycle;
      else if (trial.child.cycle == first_cycle)
        $fatal(1, "randc repeated within its cycle");
      if (trial.posts != draw || trial.child.posts != draw)
        $fatal(1, "conditional randc callbacks at draw %0d", draw);
    end
    $display("PASSED");
  end
endmodule
