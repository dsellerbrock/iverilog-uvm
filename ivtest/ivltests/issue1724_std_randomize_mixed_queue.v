module issue1724_std_randomize_mixed_queue;
  bit [7:0] x;
  bit [7:0] q[$:2];

  initial begin
    q = '{8'h00, 8'h00, 8'h00};
    std::randomize(q, x);
    if (q.size() != 3)
      $fatal(1, "unconstrained queue size changed");

    if (!std::randomize(q, x) with {
      x inside {[8'h40:8'h7f]};
      foreach (q[i]) (i < q.size()) -> q[i] == x;
    })
      $fatal(1, "mixed foreach randomize failed");
    if (q.size() != 3 || x < 8'h40 || x > 8'h7f)
      $fatal(1, "foreach randomize changed the unconstrained queue size");
    foreach (q[i])
      if (q[i] != x)
        $fatal(1, "foreach randomize did not solve queue elements with x");

    q = '{8'h12, 8'h34};
    if (!std::randomize(q, x) with {
      x inside {[8'h40:8'h7f]};
      q.size() == 3;
      foreach (q[i]) q[i] == x;
    })
      $fatal(1, "constrained mixed randomize failed");
    if (q.size() != 3 || x < 8'h40 || x > 8'h7f)
      $fatal(1, "mixed randomize returned invalid scalar or queue size");
    foreach (q[i])
      if (q[i] != x)
        $fatal(1, "scalar and queue were not solved together");

    x = 8'hde;
    q = '{8'h12, 8'h34};
    if (std::randomize(x, q) with {
      x == 8'h11;
      x == 8'h22;
      q.size() == 1;
    })
      $fatal(1, "unsatisfiable mixed randomize succeeded");
    if (x != 8'hde || q.size() != 2 || q[0] != 8'h12 || q[1] != 8'h34)
      $fatal(1, "unsatisfiable mixed randomize changed a destination");

    $display("PASSED");
  end
endmodule
