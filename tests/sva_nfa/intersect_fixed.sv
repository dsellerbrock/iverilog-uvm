// M9-NFA stage B.2: equal-length fixed `intersect` keeps the legacy
// AND-chain lowering (p->seq), so both engines lower it identically —
// verdict parity. (The NFA engine engages on the resulting plain
// chain; that is expected and must match the legacy linear engine.)
module intersect_fixed;
  logic clk = 0, a = 0, b = 0, c = 0, d = 0;
  always #5 clk = ~clk;

  e1: assert property (@(posedge clk) (a ##1 b) intersect (c ##1 d))
        $display("e1 PASS at %0t", $time);
        else $display("e1 FAIL at %0t", $time);

  initial begin
    @(negedge clk) a = 1; c = 1;
    @(negedge clk) a = 0; c = 0; b = 1; d = 1;   // both end @25 -> PASS@25
    @(negedge clk) b = 0; d = 0;
    @(negedge clk) a = 1; c = 1;
    @(negedge clk) a = 0; c = 0; b = 1;          // d=0 @45 -> FAIL@45
    @(negedge clk) b = 0;
    repeat (2) @(negedge clk);
    $finish(0);
  end
endmodule
