// Check fixed-array size/min/max locator properties assigned into queues.

module test;

  int q[5];
  int qq[$];
  int m;

  initial begin
    q = '{11, -3, 55, 22, 44};

    if (q.size != 5) begin
      $display("FAILED size");
      return;
    end

    qq = q.max;
    m = qq[0];
    if (m !== 55) begin
      $display("FAILED max");
      return;
    end

    qq = q.min;
    m = qq[0];
    if (m !== -3) begin
      $display("FAILED min");
      return;
    end

    $display("PASSED");
  end

endmodule
