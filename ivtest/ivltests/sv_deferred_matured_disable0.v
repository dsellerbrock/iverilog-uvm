module t;
  initial begin
    label_a: assert #0 (0) else $display("MATURED %m");
  end

  initial begin
    // Internal region wait used by the assertion engine: this disable runs
    // after Observed maturity but before the queued Reactive call. A mature
    // report is no longer flushable and must still execute.
    $ivl_reactive_wait;
    disable label_a;
  end

  initial #1 $display("PASSED");
endmodule
