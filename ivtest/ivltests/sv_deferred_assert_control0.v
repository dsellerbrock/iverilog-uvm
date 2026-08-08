module t;
  initial begin
    $assertoff;
    assert #0 (0) else $display("DISABLED");
    $asserton;
    assert #0 (0) else $display("KEPT");
    // Disabling checks after enqueue does not cancel an existing report.
    $assertoff;
    #1 begin
      $asserton;
      $display("PASSED");
    end
  end
endmodule
