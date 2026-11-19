class ordered_randc_fiber_leaf;
  randc bit cycle;
  rand bit gate;
  rand bit [1:0] value;
  int posts;
  constraint relation_c {
    solve gate before value;
    if (cycle) gate == 1;
  }
  constraint weighted_c {
    if (gate) value dist {0 := 1, 1 := 3, 2 := 0};
  }
  function void post_randomize(); posts++; endfunction
endclass

class ordered_randc_fiber_root;
  rand ordered_randc_fiber_leaf child;
  int posts;
  function new();
    child = new;
    srandom(32'h303701a7);
    child.srandom(32'h303702b7);
  endfunction
  function void post_randomize(); posts++; endfunction
endclass

module sv_joint_ordered_guard_randc_fiber;
  localparam int DRAWS = 512;
  ordered_randc_fiber_root trial, control;
  int zero_cycle_draws, zero_cycle_active, active_draws, active_ones;
  bit [3:0] inactive_values;
  bit saved_cycle, saved_gate;
  bit [1:0] saved_value;
  string root_rng, child_rng;

  initial begin
    trial = new;
    repeat (DRAWS) begin
      if (!trial.randomize())
        $fatal(1, "guarded randc sampling failed");
      if (trial.child.cycle && !trial.child.gate)
        $fatal(1, "cycle == 1 did not force gate");
      if (!trial.child.cycle) begin
        zero_cycle_draws++;
        if (trial.child.gate) zero_cycle_active++;
      end
      if (trial.child.gate) begin
        if (trial.child.value > 1)
          $fatal(1, "active dist admitted zero-weight or unlisted value");
        active_draws++;
        if (trial.child.value == 1) active_ones++;
      end else begin
        inactive_values[trial.child.value] = 1;
      end
    end

    // When cycle is zero there are four completions for gate == 0 and
    // two for gate == 1. Solve-before gives the gates equal probability.
    if (zero_cycle_draws != DRAWS / 2 ||
        zero_cycle_active < 104 || zero_cycle_active > 152)
      $fatal(1, "wrong cycle or ordered gate marginal: %0d / %0d",
             zero_cycle_active, zero_cycle_draws);
    if (100 * active_ones < 65 * active_draws ||
        100 * active_ones > 85 * active_draws)
      $fatal(1, "wrong active 1:3 weights: %0d / %0d", active_ones, active_draws);
    if (inactive_values != 4'b1111)
      $fatal(1, "inactive dist restricted the ordinary subject: %b", inactive_values);

    trial = new;
    control = new;
    if (!trial.randomize() || !control.randomize())
      $fatal(1, "could not establish randc history for replay");
    saved_cycle = trial.child.cycle;
    saved_gate = trial.child.gate;
    saved_value = trial.child.value;
    root_rng = trial.get_randstate();
    child_rng = trial.child.get_randstate();

    if (trial.randomize() with { child.gate == 1; child.value == 2; })
      $fatal(1, "forced active zero-weight value was accepted");
    if (trial.child.cycle != saved_cycle || trial.child.gate != saved_gate ||
        trial.child.value != saved_value || trial.posts != 1 ||
        trial.child.posts != 1 || trial.get_randstate() != root_rng ||
        trial.child.get_randstate() != child_rng)
      $fatal(1, "failed guarded call changed the transaction");
    if (!trial.randomize() || !control.randomize() ||
        trial.child.cycle != control.child.cycle ||
        trial.child.gate != control.child.gate ||
        trial.child.value != control.child.value ||
        trial.get_randstate() != control.get_randstate() ||
        trial.child.get_randstate() != control.child.get_randstate() ||
        trial.posts != 2 || trial.child.posts != 2)
      $fatal(1, "failed guarded call changed the next draw");
    $display("PASSED");
  end
endmodule
