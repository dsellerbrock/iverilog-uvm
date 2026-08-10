module t;
  bit q = 1'b0;

  initial begin
    q <= 1'b1;
    // The verdict is selected now while q is zero, not re-evaluated after NBA.
    assert final (q) else $display("FINAL_CAPTURED");
  end

  always @(q)
    if (q) $display("NBA_SETTLED");

  initial begin
    $ivl_observed_wait;
    $display("OBSERVED");
  end

  initial begin
    $ivl_reactive_wait;
    $display("REACTIVE");
  end

  initial #1 $display("PASSED");
endmodule
