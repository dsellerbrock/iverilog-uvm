module t;
  initial begin
    assert #0 (0) else $display("OBSERVED_MATURED");
    cover #0 (1) $display("OBSERVED_COVER_MATURED");
    assert final (0) else $display("FINAL_ASSERT_CANCELLED");
    cover final (1) $display("FINAL_COVER_CANCELLED");
  end

  initial begin
    // The internal wait resumes in Reactive after observed reports mature,
    // while final reports from this time slot are still pending.
    $ivl_reactive_wait;
    $assertkill(0, t);
    $asserton(0, t);
    assert #0 (0) else $display("ASSERT_REENABLED_SAME_SLOT");
    cover #0 (1) $display("COVER_REENABLED_SAME_SLOT");
    assert final (0) else $display("FINAL_ASSERT_REENABLED_SAME_SLOT");
    cover final (1) $display("FINAL_COVER_REENABLED_SAME_SLOT");
  end

  initial #1 $display("PASSED");
endmodule
