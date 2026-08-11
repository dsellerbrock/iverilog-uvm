class fixed_array_item;
  randc bit [1:0] values[3];
  randc bit [2:0] constrained[2];
  static randc bit [1:0] shared[2];
  bit force_failure;

  constraint constrained_domain {
    foreach (constrained[i]) constrained[i] inside {1, 3, 5};
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
    bit [3:0] seen[3];
    bit [7:0] constrained_seen[2];
    bit [1:0] frozen;
    bit [1:0] frozen_all[3];
    bit [1:0] before_failure[3];
    bit [3:0] shared_seen[2];

    item = new;
    alias_item = new;
    item.srandom(32'h5566_7788);
    alias_item.srandom(32'h5566_7788);

    // Keep the later cycle-completeness oracles aligned to the beginning of
    // their own cycles while the instance-mode checks exercise values[].
    item.constrained_domain.constraint_mode(0);
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
