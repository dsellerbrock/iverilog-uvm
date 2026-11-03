module test;
  bit [7:0] q[$];
  bit ok;

  initial begin
    q = '{8'h12, 8'h34};
    ok = std::randomize(q) with { q.size() > 1; };
    if (!ok || q.size() <= 1)
      $fatal(1, "open-ended queue size constraint failed");
    $display("PASSED");
  end
endmodule
