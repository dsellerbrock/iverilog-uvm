// Phase 62 / I1: covergroup illegal_bins must fire an error on match;
// ignore_bins must be excluded from coverage entirely.
//
// Pre-fix: parser deleted illegal_bins/ignore_bins data, returned
// nullptr — the bins were silently dropped.  Now they're captured in
// pform_cov_bins_t with a kind tag that propagates through elaborate
// and tgt-vvp into the runtime cov_bin_t.  The %covgrp/sample
// opcode emits an ERROR to stderr when an illegal_bin matches and
// ignore_bins are stripped during elaboration so they never appear
// as coverable bins.
`timescale 1ns/1ps
module top;
  class my_cg;
    int v;
    covergroup cg_t;
      cp_v: coverpoint v {
	bins lo  = {[0:9]};
	bins hi  = {[20:29]};
	ignore_bins ig = {[10:19]};
	illegal_bins bad = {[30:39]};
      }
    endgroup
    function new(); cg_t = new(); endfunction
    function void sample(int x); v = x; cg_t.sample(); endfunction
  endclass

  initial begin
    my_cg c = new();
    real cov;
    c.sample(5);   // hits bins lo
    c.sample(25);  // hits bins hi
    c.sample(15);  // hits ignore_bins (no-op, excluded from coverage)
    c.sample(35);  // hits illegal_bins — runtime emits ERROR to stderr
    cov = c.cg_t.get_inst_coverage();
    $display("coverage = %0.2f", cov);
    if (cov != 100.0) begin
      $display("FAIL: expected 100.0 (2 of 2 normal bins), got %0.2f", cov);
      $fatal(1, "I1 regression: ignore/illegal bins counted toward denominator");
    end
    $display("PASS: ignore_bins excluded; illegal_bins flagged via stderr");
    $finish;
  end
endmodule
