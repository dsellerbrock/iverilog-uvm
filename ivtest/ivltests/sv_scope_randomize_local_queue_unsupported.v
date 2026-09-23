module test;
  bit [7:0] q[$];
  bit [7:0] bounded_q[$:1];
  bit ok;

  initial begin
    q = '{8'h12, 8'h34};
    ok = std::randomize(q) with { q.size() > 1; };
    if (ok || q.size() != 2 || q[0] != 8'h12 || q[1] != 8'h34)
      $fatal(1, "nonexact size changed the queue");

    ok = std::randomize(q) with { q.size() == 65537; };
    if (ok || q.size() != 2 || q[0] != 8'h12 || q[1] != 8'h34)
      $fatal(1, "oversize changed the queue");

    bounded_q = '{8'h12, 8'h34};
    ok = std::randomize(bounded_q) with { bounded_q.size() == 3; };
    if (ok || bounded_q.size() != 2 || bounded_q[0] != 8'h12
        || bounded_q[1] != 8'h34)
      $fatal(1, "declared maximum changed the queue");
    $display("PASSED");
  end
endmodule
