class ordered_guard_leaf;
  rand bit gate;
  rand bit [1:0] value;
  constraint c {
    solve gate before value;
    gate dist {0 := 7, 1 := 3};
    value inside {[0:2]};
    if (gate) value dist {0 := 1, 1 := 3, 2 := 1};
  }
endclass

class ordered_guard_plain_leaf;
  rand bit gate;
  rand bit [1:0] value;
  constraint c {
    solve gate before value;
    value inside {[0:2]};
  }
endclass

class ordered_guard_root;
  rand ordered_guard_leaf a;
  rand ordered_guard_plain_leaf b;
  int posts;
  constraint c { a.gate == b.gate; a.value == b.value; }
  function new(); a = new; b = new; endfunction
  function void post_randomize(); posts++; endfunction
endclass

module sv_joint_ordered_guard_fiber;
  ordered_guard_root trial, control;
  int active, active_one, inactive[3];
  bit saved_gate;
  bit [1:0] saved_value;
  string root_rng, a_rng, b_rng;
  initial begin
    trial = new;
    trial.srandom(32'h47f1be);
    repeat (4096) begin
      if (!trial.randomize() || trial.a.gate != trial.b.gate ||
          trial.a.value != trial.b.value || trial.a.value > 2)
        $fatal(1, "ordered guard fiber failed");
      if (trial.a.gate) begin
        active++;
        if (trial.a.value == 1) active_one++;
      end else inactive[trial.a.value]++;
    end
    if (active < 1000 || active > 1500 ||
        active_one < 550 || active_one > 950)
      $fatal(1, "guard/active weights %0d %0d", active, active_one);
    foreach (inactive[i])
      if (inactive[i] < 400)
        $fatal(1, "inactive subject lost ordinary fiber %0d=%0d", i, inactive[i]);
    repeat (32) begin
      if (!trial.randomize() with { a.gate == 1; } || !trial.a.gate)
        $fatal(1, "forced active fiber");
      if (!trial.randomize() with { a.gate == 0; } || trial.a.gate ||
          trial.a.value > 2)
        $fatal(1, "forced inactive fiber");
    end
    control = new;
    control.srandom(32'h47f1c0);
    trial.srandom(32'h47f1c0);
    if (!trial.randomize() || !control.randomize()) $fatal(1, "replay setup");
    saved_gate = trial.a.gate;
    saved_value = trial.a.value;
    root_rng = trial.get_randstate();
    a_rng = trial.a.get_randstate();
    b_rng = trial.b.get_randstate();
    if (trial.randomize() with { a.gate == 1; a.value == 3; } ||
        trial.a.gate != saved_gate || trial.a.value != saved_value ||
        trial.b.gate != saved_gate || trial.b.value != saved_value ||
        trial.get_randstate() != root_rng || trial.a.get_randstate() != a_rng ||
        trial.b.get_randstate() != b_rng || trial.posts != 4161)
      $fatal(1, "failed guarded call changed transaction");
    if (!trial.randomize() || !control.randomize() ||
        trial.a.gate != control.a.gate || trial.a.value != control.a.value)
      $fatal(1, "failed guarded call consumed a draw");
    $display("PASSED");
  end
endmodule
