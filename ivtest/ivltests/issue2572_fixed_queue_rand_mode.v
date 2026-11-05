class issue2572_family_1d;
  rand bit [3:0] q[2][$];
endclass

class issue2572_plain_queue;
  rand bit [3:0] q[$];
endclass

class issue2572_family_2d;
  rand bit [3:0] q[2][2][$];
endclass

module main;
  initial begin
    issue2572_family_1d one;
    issue2572_family_1d one_a;
    issue2572_plain_queue plain;
    issue2572_family_2d two;
    issue2572_family_2d two_a;
    int one_disabled_changes;
    int one_enabled_changes;
    int family_enabled_changes;
    int plain_enabled_changes;
    int two_word_disabled_changes;
    int two_element_enabled_changes;
    int two_family_enabled_changes;
    int iter;

    one = new;
    one_a = new;
    plain = new;
    two = new;
    two_a = new;
    one.srandom(32'h2572_0001);
    one_a.srandom(32'h2572_0004);
    plain.srandom(32'h2572_0002);
    two.srandom(32'h2572_0003);
    two_a.srandom(32'h2572_0005);
    one.q[0] = '{0, 0};
    one.q[1] = '{0, 0};
    one_a.q[0] = '{0, 0};
    one_a.q[1] = '{0, 0};
    plain.q = '{0, 0};
    foreach (two.q[i,j]) two.q[i][j] = '{0, 0};
    foreach (two_a.q[i,j]) two_a.q[i][j] = '{0, 0};

    // A queue-word disable applies to all its elements; a later element
    // enable overrides only that queue element.
    one_a.q[0].rand_mode(0);
    one_a.q[0][1].rand_mode(1);
    // A whole-family enable overrides an earlier queue-element disable.
    one.q[1][0].rand_mode(0);
    one.q.rand_mode(1);
    // Plain dynamic queues retain their existing whole-property behavior.
    plain.q[0].rand_mode(0);
    plain.q.rand_mode(1);

    // The same ordering applies through a second fixed-array dimension.
    two.q[0][0].rand_mode(0);
    two.q[0][0][1].rand_mode(1);
    two.q[1][0][0].rand_mode(0);
    two.q.rand_mode(1);
    two.q[1][1][0].rand_mode(0);
    two.q[1][1].rand_mode(1);
    two_a.q[0][0].rand_mode(0);
    two_a.q[0][0][1].rand_mode(1);

    for (iter = 0; iter < 32; iter++) begin
      if (!one.randomize() || !one_a.randomize() || !plain.randomize()
          || !two.randomize() || !two_a.randomize())
        $fatal(1, "randomize failed");
      if (one_a.q[0][0] != 0) one_disabled_changes++;
      if (one_a.q[0][1] != 0) one_enabled_changes++;
      if (one.q[1][0] != 0) family_enabled_changes++;
      if (plain.q[0] != 0) plain_enabled_changes++;
      if (two_a.q[0][0][0] != 0) two_word_disabled_changes++;
      if (two_a.q[0][0][1] != 0) two_element_enabled_changes++;
      if (two.q[1][0][0] != 0) two_family_enabled_changes++;

      foreach (one.q[i,k]) one.q[i][k] = 0;
      foreach (one_a.q[i,k]) one_a.q[i][k] = 0;
      foreach (plain.q[k]) plain.q[k] = 0;
      foreach (two.q[i,j,k]) two.q[i][j][k] = 0;
      foreach (two_a.q[i,j,k]) two_a.q[i][j][k] = 0;
    end

    if (one_disabled_changes != 0 || one_enabled_changes == 0
        || family_enabled_changes == 0 || plain_enabled_changes == 0
        || two_word_disabled_changes != 0 || two_element_enabled_changes == 0
        || two_family_enabled_changes == 0)
      $fatal(1, "rand_mode override ordering failed: %0d %0d %0d %0d %0d %0d %0d",
             one_disabled_changes, one_enabled_changes, family_enabled_changes,
             plain_enabled_changes, two_word_disabled_changes,
             two_element_enabled_changes, two_family_enabled_changes);

    $display("PASSED");
  end
endmodule
