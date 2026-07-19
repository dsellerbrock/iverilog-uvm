// M9-NFA stage B.5: `throughout` over a VARIABLE-length sequence -- the
// legacy engine sorries (variable window); the automaton engine ANDs
// the invariant onto every tick edge, so it is checked at the variable
// wait cycles too. The cover counts only the windows where the
// invariant held for the ENTIRE (variable) span.
module throughout_nfa_only;
  logic clk = 0, g=0, x=0, y=0;
  always #5 clk = ~clk;

  tc: cover property (@(posedge clk) g throughout (x ##[1:2] y));   // inst 0

  initial begin
    // I1: x@15,y@25 (##1, span [15,25]); g holds @15,@25 -> counts.
    @(negedge clk) x=1; g=1;
    @(negedge clk) x=0; g=1; y=1;
    @(negedge clk) g=0; y=0;
    @(negedge clk);
    // I2: x@45,y@65 (##2, span [45,65]); g drops @55 (a WAIT cycle) -> no count.
    @(negedge clk) x=1; g=1;
    @(negedge clk) x=0; g=0;
    @(negedge clk) g=1; y=1;
    @(negedge clk) g=0; y=0;
    @(negedge clk);
    // I3: x@95,y@115 (##2, span [95,115]); g holds all three -> counts.
    @(negedge clk) x=1; g=1;
    @(negedge clk) x=0; g=1;
    @(negedge clk) g=1; y=1;
    @(negedge clk) g=0; y=0;
    @(negedge clk);
    $display("throughout cover=%0d (expect 2: I1 + I3; I2 drops g mid-window)",
             _ivl_sva0_cnt0);
    $finish(0);
  end
endmodule
