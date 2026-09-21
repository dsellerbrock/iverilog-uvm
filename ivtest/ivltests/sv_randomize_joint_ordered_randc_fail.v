class ordered_randc_fail_leaf;
  rand bit [7:0] value;
endclass

class ordered_randc_unsat;
  randc bit [1:0] cycle;
  rand bit [1:0] early, late;
  rand ordered_randc_fail_leaf child;
  int posts;
  function new; child = new; endfunction
  function void post_randomize; posts++; endfunction
  constraint order_c { solve early before late; }
  constraint relation_c { cycle == early; child.value == late; }
endclass

class ordered_randc_excluded_dist;
  randc bit cycle;
  rand bit early;
  rand bit [1:0] value;
  rand ordered_randc_fail_leaf child;
  int posts;
  function new; child = new; endfunction
  function void post_randomize; posts++; endfunction
  constraint order_c { solve early before value; }
  constraint relation_c {
    early == cycle;
    value == cycle;
    child.value == value;
    value dist {[0:1] := 1};
  }
endclass

class ordered_randc_cap;
  randc bit cycle;
  rand bit gate;
  rand bit [9:0] data;
  rand ordered_randc_fail_leaf child;
  int posts;
  function new; child = new; endfunction
  function void post_randomize; posts++; endfunction
  constraint order_c { solve gate before data; }
  constraint relation_c {
    cycle <= data[0];
    gate == data[1];
    child.value == data[9:2];
  }
endclass

module test;
  ordered_randc_unsat subject = new;
  ordered_randc_unsat control = new;
  ordered_randc_cap cap = new;
  ordered_randc_excluded_dist excluded = new;
  string subject_rng, child_rng;
  bit [1:0] old_cycle, old_early, old_late;
  bit [7:0] old_child;

  initial begin
    subject.cycle = 2'd1;
    subject.early = 2'd2;
    subject.late = 2'd3;
    subject.child.value = 8'h5a;
    subject.srandom(32'h524f4c4c);
    subject.child.srandom(32'h524f4c43);
    old_cycle = subject.cycle;
    old_early = subject.early;
    old_late = subject.late;
    old_child = subject.child.value;
    subject_rng = subject.get_randstate();
    child_rng = subject.child.get_randstate();
    if (subject.randomize() with { 1'b0; })
      $fatal(1, "contradictory ordered randc solve succeeded");
    if (subject.cycle !== old_cycle || subject.early !== old_early
        || subject.late !== old_late || subject.child.value !== old_child
        || subject.posts != 0)
      $fatal(1, "failed ordered randc solve changed values/callbacks");
    if (subject.get_randstate() != subject_rng
        || subject.child.get_randstate() != child_rng)
      $fatal(1, "failed ordered randc solve changed RNG");

    // Matching control proves the failed call consumed no cyclic history.
    control.cycle = old_cycle;
    control.early = old_early;
    control.late = old_late;
    control.child.value = old_child;
    control.srandom(32'h524f4c4c);
    control.child.srandom(32'h524f4c43);
    if (!subject.randomize() || !control.randomize())
      $fatal(1, "post-failure controls failed");
    if (subject.cycle != control.cycle || subject.early != control.early
        || subject.late != control.late
        || subject.child.value != control.child.value)
      $fatal(1, "failed solve consumed randc history or RNG");

    // The existing exact ordered-dist policy requires every source range
    // member to remain available in each proved prefix. This relation leaves
    // only one member per randc prefix, so rejection must precede all draws.
    excluded.cycle = 1'b1;
    excluded.early = 1'b1;
    excluded.value = 2'd1;
    excluded.child.value = 8'h1;
    excluded.srandom(32'h45584352);
    excluded.child.srandom(32'h45584343);
    subject_rng = excluded.get_randstate();
    child_rng = excluded.child.get_randstate();
    if (excluded.randomize())
      $fatal(1, "excluded ordered-dist randc fiber succeeded");
    if (excluded.cycle !== 1'b1 || excluded.early !== 1'b1
        || excluded.value !== 2'd1 || excluded.child.value !== 8'h1
        || excluded.posts != 0)
      $fatal(1, "excluded-fiber failure changed values/callbacks");
    if (excluded.get_randstate() != subject_rng
        || excluded.child.get_randstate() != child_rng)
      $fatal(1, "excluded-fiber failure changed RNG before preflight");

    // The coupled component has 1536 solutions, beyond the fixed 1024
    // exact-table cap. It must reject before the implicit randc draw.
    cap.cycle = 1'b1;
    cap.gate = 1'b1;
    cap.data = 10'h3ff;
    cap.child.value = 8'hff;
    cap.srandom(32'h43415052);
    cap.child.srandom(32'h43415043);
    subject_rng = cap.get_randstate();
    child_rng = cap.child.get_randstate();
    if (cap.randomize()) $fatal(1, "over-cap ordered randc solve succeeded");
    if (cap.cycle !== 1'b1 || cap.gate !== 1'b1 || cap.data !== 10'h3ff
        || cap.child.value !== 8'hff || cap.posts != 0)
      $fatal(1, "over-cap failure changed values/callbacks");
    if (cap.get_randstate() != subject_rng
        || cap.child.get_randstate() != child_rng)
      $fatal(1, "over-cap failure changed RNG before preflight completed");

    $display("PASSED");
  end
endmodule
