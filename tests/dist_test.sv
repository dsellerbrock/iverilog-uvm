// dist_test.sv - verify `dist` constraints parse and randomize succeeds.
// Exact weighted sampling is covered by the focused single-distribution
// regressions; this file deliberately retains two distributions on one
// property as a compatibility smoke test for that documented approximation.

class C;
  rand int x;
  // Per-value weights: each member of [1:5] has weight 60; 6 has weight 40.
  constraint c_dist { x dist {[1:5]:=60, 6:=40}; }
  // Soft variant
  constraint c_soft { soft x dist {[1:10]:=70, [11:20]:=30}; }
endclass

module top;
  initial begin
    C c = new;
    int ok = 0;
    for (int i = 0; i < 10; i++) begin
      if (c.randomize() == 1) ok++;
    end
    if (ok == 10) $display("PASS dist constraint parses, randomize succeeds %0d/10", ok);
    else          $display("FAIL only %0d/10 randomize calls succeeded", ok);
    $finish;
  end
endmodule
