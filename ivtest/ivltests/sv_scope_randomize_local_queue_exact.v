module test;
  bit [7:0] q[$];
  logic signed [7:0] signed_q[$];
  bit [7:0] bounded_q[$:1];
  int requested;
  bit ok;

  initial begin
    requested = 3;
    ok = std::randomize(q) with {
      q.size() == requested;
      q[0] == 8'h12;
      foreach (q[i]) q[i] < 8'h80;
    };
    if (!ok || q.size() != 3 || q[0] != 8'h12)
      $fatal(1, "queue size/element solve failed");
    foreach (q[i])
      if (q[i] >= 8'h80) $fatal(1, "queue foreach solve failed");

    ok = std::randomize(signed_q) with {
      signed_q.size() == 1;
      signed_q[0] == -8'sd2;
    };
    if (!ok || signed_q.size() != 1 || signed_q[0] != -8'sd2)
      $fatal(1, "signed four-state queue element solve failed");

    ok = std::randomize(bounded_q) with { bounded_q.size() == 2; };
    if (!ok || bounded_q.size() != 2)
      $fatal(1, "bounded queue maximum size solve failed");

    requested = 0;
    ok = std::randomize(q) with {
      q.size() == requested;
      foreach (q[i]) q[i] == 8'hff;
    };
    if (!ok || q.size() != 0)
      $fatal(1, "queue zero-size solve failed");

    q = '{8'h12, 8'h34};
    ok = std::randomize(q) with {
      q.size() == 1;
      q.size() == 2;
    };
    if (ok || q.size() != 2 || q[0] != 8'h12 || q[1] != 8'h34)
      $fatal(1, "UNSAT mutated the queue");
    $display("PASSED");
  end
endmodule
