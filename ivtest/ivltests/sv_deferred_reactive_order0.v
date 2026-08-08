module t;
  initial begin
    assert #0 (0) else $display("REACTIVE");
    // A delay is not a deferred-report flush point. This Inactive-region
    // print must precede the assertion action in Reactive.
    #0 $display("INACTIVE");
  end

  initial #1 $display("PASSED");
endmodule
