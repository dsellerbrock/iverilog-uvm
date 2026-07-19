// M9-NFA stage B.4: fixed-length `within` keeps the legacy op-8
// $past-sampled lowering under BOTH engines (the NFA hook only takes
// non-fixed shapes), so this is a verdict-parity check.
// NFA-EXPECT-FALLBACK
module within_fixed;
  logic clk = 0, b=0, x=0;
  always #5 clk = ~clk;

  // b within (x ##1 x ##1 x): b true somewhere in a fixed 3-cycle x run
  w: assert property (@(posedge clk) b within (x ##1 x ##1 x))
        else $display("WFAIL at %0t", $time);

  initial begin
    @(negedge clk) x=1; b=1;      // x run starts; b at cycle 0
    @(negedge clk) x=1; b=0;
    @(negedge clk) x=1;           // 3-cycle x run done; b was inside -> ok
    @(negedge clk) x=0;
    @(negedge clk) x=1;           // new run
    @(negedge clk) x=1;
    @(negedge clk) x=1;           // b never rose in this run -> within fails
    @(negedge clk) x=0;
    repeat(2) @(negedge clk);
    $finish(0);
  end
endmodule
