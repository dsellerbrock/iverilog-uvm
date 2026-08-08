module t;
  // A final procedure runs after the iterative Observed/Reactive regions.
  // Until this context has defined lowering, it must fail loudly rather than
  // enqueue a report that can never mature.
  final assert #0 (0) else $display("MUST NOT DISAPPEAR");
endmodule
