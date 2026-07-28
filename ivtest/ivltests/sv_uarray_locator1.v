// Check fixed-array size/min/max locator properties assigned into queues.

module test;

  int q[5];
  int qq[$];
  int m;

  // NB: `return' is only legal inside tasks/functions (IEEE 1800-2017
  // 13.4.4); the original form of this test used it directly in the
  // initial block, so rejecting the test was conformant behavior.
  initial begin : blk
    q = '{11, -3, 55, 22, 44};

    if (q.size != 5) begin
      $display("FAILED size");
      disable blk;
    end

    qq = q.max;
    m = qq[0];
    if (m !== 55) begin
      $display("FAILED max");
      disable blk;
    end

    qq = q.min;
    m = qq[0];
    if (m !== -3) begin
      $display("FAILED min");
      disable blk;
    end

    $display("PASSED");
  end

endmodule
