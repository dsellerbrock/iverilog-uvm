class issue2572_cyclic_queues;
  randc bit [3:0] q[2][2][$];
endclass

class issue2572_rand_queues;
  rand bit [3:0] q[2][2][$];
endclass

module main;
  issue2572_cyclic_queues cyclic;
  issue2572_rand_queues constrained;
  bit [15:0] seen;

  initial begin
    constrained = new;
    constrained.q[1][0] = '{0, 0};
    constrained.q.rand_mode(0);
    constrained.q[1][0][1].rand_mode(1);
    if (!constrained.randomize() with { q[1][0][1] == 9; })
      $fatal(1, "constraint on re-enabled element failed");
    if (constrained.q[1][0][1] != 9 || constrained.q[1][0][0] != 0)
      $fatal(1, "constraint did not update only the selected element");

    if (constrained.randomize() with { q[1][0][0] == 1; })
      $fatal(1, "randomize accepted an incompatible disabled element");
    if (constrained.randomize() with { q[1][0].size() == 3; })
      $fatal(1, "randomize accepted an incompatible disabled queue size");
    if (constrained.q[1][0].size() != 2 ||
        constrained.q[1][0][1] != 9 || constrained.q[1][0][0] != 0)
      $fatal(1, "failed randomize changed the queue");

    cyclic = new;
    foreach (cyclic.q[i,j]) cyclic.q[i][j] = '{0, 0};
    // Leave every fixed slot off and enable just one inner element.
    cyclic.q.rand_mode(0);
    cyclic.q[1][0][1].rand_mode(1);

    repeat (16) begin
      if (!cyclic.randomize()) $fatal(1, "unconstrained randomize failed");
      seen[cyclic.q[1][0][1]] = 1;
      foreach (cyclic.q[i,j]) begin
        if (cyclic.q[i][j].size() != 2)
          $fatal(1, "q[%0d][%0d] changed size", i, j);
        foreach (cyclic.q[i][j][k])
          if ((i != 1 || j != 0 || k != 1) && cyclic.q[i][j][k] != 0)
            $fatal(1, "disabled q[%0d][%0d][%0d] changed", i, j, k);
      end
    end
    if (seen != '1)
      $fatal(1, "selected element visited %0d/16 values (mask %h)",
             $countones(seen), seen);
    $display("PASSED");
  end
endmodule
