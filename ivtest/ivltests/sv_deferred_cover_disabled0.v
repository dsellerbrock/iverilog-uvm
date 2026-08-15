module deferred_observed_cover_disabled;
  initial disabled_observed: cover #0 (1)
    $fatal(1, "disabled observed cover executed");
endmodule

module deferred_final_cover_disabled;
  final disabled_final: cover final (1)
    $fatal(1, "disabled final cover executed");
endmodule

module deferred_simple_assertion_disabled;
  initial disabled_simple: assert (1)
    $fatal(1, "disabled simple assertion executed");
endmodule

module deferred_concurrent_assertion_disabled;
  bit clk;
  initial disabled_concurrent: assert property (@(posedge clk) 1)
    $fatal(1, "disabled concurrent assertion executed");
endmodule
