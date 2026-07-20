// M9-NFA stage B.4: `within` with a non-fixed (windowed) right operand
// -- the legacy engine sorries ("fixed-length only"); the automaton
// engine lowers `s1 within s2` as (padded s1) intersect s2, so the s1
// match must lie inside s2's exact interval. Three cover properties
// place b at the START, MIDDLE, and END of the matched window; each
// must count exactly the intervals where b actually falls inside.
module within_nfa_only;
  logic clk = 0, b=0, x=0, y=0;
  always #5 clk = ~clk;

  wc: cover property (@(posedge clk) b within (x ##[1:2] y));   // inst 0

  initial begin
    // I1: x@15,y@25 -> [15,25] (##1). b@15 at START -> counts.
    @(negedge clk) x=1; b=1;
    @(negedge clk) x=0; b=0; y=1;
    @(negedge clk) y=0;
    @(negedge clk);
    // I2: x@45, y@65 -> [45,65] (##2). b@55 in MIDDLE -> counts.
    @(negedge clk) x=1;
    @(negedge clk) x=0; b=1;
    @(negedge clk) b=0; y=1;
    @(negedge clk) y=0;
    @(negedge clk);
    // I3: x@95, y@105 -> [95,105] (##1). b never rises -> does NOT count.
    @(negedge clk) x=1;
    @(negedge clk) x=0; y=1;
    @(negedge clk) y=0;
    @(negedge clk);
    // I4: x@135, y@145 -> [135,145] (##1). b@145 at END -> counts.
    @(negedge clk) x=1;
    @(negedge clk) x=0; y=1; b=1;
    @(negedge clk) y=0; b=0;
    @(negedge clk);
    $display("within cover=%0d (expect 3: I1 start, I2 middle, I4 end; I3 none)",
             _ivl_sva0_cnt0);
    $finish(0);
  end
endmodule
