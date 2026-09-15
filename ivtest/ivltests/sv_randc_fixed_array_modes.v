class fixed_array_item;
  randc bit [1:0] values[3];
  randc bit [2:0] constrained[2];
  static randc bit [1:0] shared[2];
  bit force_failure;

  constraint constrained_domain {
    foreach (constrained[i]) constrained[i] inside {1, 3, 5};
  }
  constraint constrained_relation {
    constrained[0] != constrained[1];
  }
  constraint deliberate_failure {
    if (force_failure) values[0] != values[0];
  }
endclass

module test;
  initial begin
    fixed_array_item item;
    fixed_array_item alias_item;
    fixed_array_item coupled_item;
    fixed_array_item peer_one_item;
    fixed_array_item peer_three_item;
    bit [3:0] seen[3];
    bit [7:0] constrained_seen[2];
    bit [1:0] frozen;
    bit [1:0] frozen_all[3];
    bit [1:0] before_failure[3];
    bit [3:0] shared_seen[2];

    item = new;
    alias_item = new;
    coupled_item = new;
    peer_one_item = new;
    peer_three_item = new;
    item.srandom(32'h5566_7788);
    alias_item.srandom(32'h5566_7788);
    coupled_item.srandom(32'h5566_7788);
    peer_one_item.srandom(32'h5566_7788);
    peer_three_item.srandom(32'h5566_7788);

    // Keep the later cycle-completeness oracles aligned to the beginning of
    // their own cycles while the instance-mode checks exercise values[].
    item.constrained_domain.constraint_mode(0);
    item.constrained_relation.constraint_mode(0);
    item.constrained.rand_mode(0);
    item.shared.rand_mode(0);
    item.shared[1].rand_mode(1);
    if (alias_item.shared[0].rand_mode() !== 0
        || alias_item.shared[1].rand_mode() !== 1
        || alias_item.shared.rand_mode() !== 0)
      $fatal(1, "static per-leaf mode was not canonical across receivers");
    alias_item.shared.rand_mode(0);

    if (item.values.rand_mode() !== 1
        || item.values[0].rand_mode() !== 1
        || item.values[1].rand_mode() !== 1
        || item.values[2].rand_mode() !== 1)
      $fatal(1, "fixed-array modes did not start enabled");

    for (int sample = 0; sample < 2; sample++) begin
      if (item.randomize() !== 1)
        $fatal(1, "fixed-array warmup randomize failed");
      for (int leaf = 0; leaf < 3; leaf++) begin
        if (seen[leaf][item.values[leaf]])
          $fatal(1, "fixed-array leaf repeated during warmup");
        seen[leaf][item.values[leaf]] = 1'b1;
      end
    end

    for (int leaf = 0; leaf < 3; leaf++)
      before_failure[leaf] = item.values[leaf];
    item.force_failure = 1'b1;
    if (item.randomize() !== 0)
      $fatal(1, "contradictory fixed-array randomize unexpectedly succeeded");
    for (int leaf = 0; leaf < 3; leaf++)
      if (item.values[leaf] !== before_failure[leaf])
        $fatal(1, "failed fixed-array randomize leaked a candidate value");
    item.force_failure = 1'b0;

    item.values[1].rand_mode(0);
    if (item.values[0].rand_mode() !== 1
        || item.values[1].rand_mode() !== 0
        || item.values[2].rand_mode() !== 1
        || item.values.rand_mode() !== 0)
      $fatal(1, "mixed indexed/aggregate mode query was incorrect");
    frozen = item.values[1];

    for (int sample = 0; sample < 2; sample++) begin
      if (item.randomize() !== 1)
        $fatal(1, "fixed-array randomize failed");
      if (item.values[1] !== frozen)
        $fatal(1, "disabled fixed-array leaf changed");
      foreach (item.values[leaf]) begin
        if (leaf == 1) continue;
        if (seen[leaf][item.values[leaf]])
          $fatal(1, "enabled fixed-array leaf repeated");
        seen[leaf][item.values[leaf]] = 1'b1;
      end
    end
    if (seen[0] !== 4'b1111 || seen[2] !== 4'b1111)
      $fatal(1, "enabled fixed-array leaves did not complete cycles");

    item.values[1].rand_mode(1);
    for (int sample = 0; sample < 2; sample++) begin
      if (item.randomize() !== 1)
        $fatal(1, "re-enabled fixed-array randomize failed");
      if (seen[1][item.values[1]])
        $fatal(1, "re-enabled leaf did not resume its prior cycle");
      seen[1][item.values[1]] = 1'b1;
    end
    if (seen[1] !== 4'b1111 || item.values.rand_mode() !== 1)
      $fatal(1, "re-enabled leaf did not complete its paused cycle");

    for (int leaf = 0; leaf < 3; leaf++)
      frozen_all[leaf] = item.values[leaf];
    item.values.rand_mode(0);
    if (item.values.rand_mode() !== 0
        || item.values[0].rand_mode() !== 0
        || item.values[1].rand_mode() !== 0
        || item.values[2].rand_mode() !== 0)
      $fatal(1, "whole-array setter did not disable every leaf");
    if (item.randomize() !== 1)
      $fatal(1, "all-disabled randomize failed");
    for (int leaf = 0; leaf < 3; leaf++)
      if (item.values[leaf] !== frozen_all[leaf])
        $fatal(1, "whole-array rand_mode(0) did not freeze every leaf");
    item.values.rand_mode(1);

    // Each constrained leaf cycles independently over its exact feasible set.
    // Keep the cross-leaf relation disabled here: 18.4.2 permits a new
    // permutation whenever no remaining value can satisfy the constraints.
    item.constrained_domain.constraint_mode(1);
    for (int leaf = 0; leaf < 2; leaf++)
      constrained_seen[leaf] = '0;
    // An explicit randomize(variable) selection overrides rand_mode for that
    // call without changing the stored mode (18.11 versus 18.8).
    item.constrained.rand_mode(0);
    item.constrained[0] = 0;
    item.constrained[1] = 0;
    if (item.randomize(constrained) !== 1)
      $fatal(1, "explicit fixed-array selection failed");
    if (item.constrained.rand_mode() !== 0)
      $fatal(1, "explicit selection changed stored fixed-array mode");
    for (int leaf = 0; leaf < 2; leaf++) begin
      if (!(item.constrained[leaf] inside {1, 3, 5}))
        $fatal(1, "explicitly selected leaf escaped feasible set");
      constrained_seen[leaf][item.constrained[leaf]] = 1'b1;
    end
    item.constrained.rand_mode(1);
    for (int sample = 1; sample < 3; sample++) begin
      if (item.randomize() !== 1)
        $fatal(1, "constrained fixed-array randomize failed");
      for (int leaf = 0; leaf < 2; leaf++) begin
        if (!(item.constrained[leaf] inside {1, 3, 5}))
          $fatal(1, "constrained leaf escaped feasible set");
        if (constrained_seen[leaf][item.constrained[leaf]])
          $fatal(1, "constrained randc leaf repeated within feasible cycle");
        constrained_seen[leaf][item.constrained[leaf]] = 1'b1;
      end
    end
    if (constrained_seen[0] !== 8'b0010_1010
        || constrained_seen[1] !== 8'b0010_1010)
      $fatal(1, "constrained leaves did not cover exact feasible set");

    // Exercise the coupled constraint separately without inferring either
    // leaf's hidden permutation state. Section 18.4.2 permits recomputing a
    // permutation when its remaining values cannot satisfy the constraint.
    coupled_item.values.rand_mode(0);
    coupled_item.shared.rand_mode(0);
    coupled_item.constrained_domain.constraint_mode(1);
    coupled_item.constrained_relation.constraint_mode(1);
    for (int sample = 0; sample < 12; sample++) begin
      if (coupled_item.randomize() !== 1)
        $fatal(1, "coupled constrained fixed-array randomize failed");
      if (!(coupled_item.constrained[0] inside {1, 3, 5})
          || !(coupled_item.constrained[1] inside {1, 3, 5})
          || coupled_item.constrained[0] == coupled_item.constrained[1])
        $fatal(1, "coupled constrained leaves violated their domain or relation");
    end

    // Make the feasible permutation directly observable by freezing the peer
    // on fresh objects. The active leaf must cycle over the two remaining
    // domain values without a repeat; no prior constraint history is involved.
    peer_one_item.values.rand_mode(0);
    peer_one_item.shared.rand_mode(0);
    peer_one_item.constrained.rand_mode(0);
    peer_one_item.constrained[0].rand_mode(1);
    peer_one_item.constrained[1] = 1;
    constrained_seen[0] = '0;
    repeat (2) begin
      if (peer_one_item.randomize() !== 1)
        $fatal(1, "fixed-peer-one constrained randomize failed");
      if (constrained_seen[0][peer_one_item.constrained[0]])
        $fatal(1, "fixed-peer-one feasible randc value repeated");
      constrained_seen[0][peer_one_item.constrained[0]] = 1'b1;
    end
    if (constrained_seen[0] !== 8'b0010_1000)
      $fatal(1, "fixed-peer-one leaf did not cover its exact feasible cycle");

    peer_three_item.values.rand_mode(0);
    peer_three_item.shared.rand_mode(0);
    peer_three_item.constrained.rand_mode(0);
    peer_three_item.constrained[0].rand_mode(1);
    peer_three_item.constrained[1] = 3;
    constrained_seen[0] = '0;
    repeat (2) begin
      if (peer_three_item.randomize() !== 1)
        $fatal(1, "fixed-peer-three constrained randomize failed");
      if (constrained_seen[0][peer_three_item.constrained[0]])
        $fatal(1, "fixed-peer-three feasible randc value repeated");
      constrained_seen[0][peer_three_item.constrained[0]] = 1'b1;
    end
    if (constrained_seen[0] !== 8'b0010_0010)
      $fatal(1, "fixed-peer-three leaf did not cover its exact feasible cycle");

    // Static fixed-array history is shared through every receiver.
    item.shared.rand_mode(1);
    if (alias_item.shared.rand_mode() !== 1)
      $fatal(1, "static fixed-array mode was not shared by receivers");
    for (int sample = 0; sample < 4; sample++) begin
      bit success;
      if (sample[0]) success = alias_item.randomize();
      else success = item.randomize();
      if (success !== 1)
        $fatal(1, "static fixed-array randomize failed");
      for (int leaf = 0; leaf < 2; leaf++) begin
        if (shared_seen[leaf][fixed_array_item::shared[leaf]])
          $fatal(1, "static fixed-array history forked by receiver");
        shared_seen[leaf][fixed_array_item::shared[leaf]] = 1'b1;
      end
    end
    if (shared_seen[0] !== 4'b1111 || shared_seen[1] !== 4'b1111)
      $fatal(1, "static fixed-array leaves did not share complete cycles");

    $display("PASSED");
  end
endmodule
