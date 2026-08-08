module t;
  // The assertion label introduces a child scope; the final-context check
  // must therefore walk scope ancestors rather than inspect only this scope.
  final labeled_a: assert #0 (0) else $display("MUST NOT DISAPPEAR");
endmodule
