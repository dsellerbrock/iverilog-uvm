// M9-NFA stage A.3 win: cover of a MID-chain window — the legacy
// engine sorries; the automaton engine counts per accepting attempt.
// The count is displayed into the verdict stream and checked against
// the hand-computed gold.
module cover_midchain_nfa_only;
  logic clk = 0, a = 0, b = 0, c = 0;
  always #5 clk = ~clk;

  cm: cover property (@(posedge clk) a ##[1:2] b ##1 c);  // inst 0

  initial begin
    @(negedge clk) a = 1;            // a@15: b@25 or b@35
    @(negedge clk) a = 0; b = 1;     // b@25 (1st slot)
    @(negedge clk) b = 0; c = 1;     // c@35: covered (1)
    @(negedge clk) c = 0;
    @(negedge clk) a = 1;            // a@55: b@65 or b@75
    @(negedge clk) a = 0;
    @(negedge clk) b = 1;            // b@75 (2nd slot)
    @(negedge clk) b = 0;            // c@85=0: attempt dies, not covered
    @(negedge clk);
    $display("cm count=%0d", _ivl_sva0_cnt0);
    $finish(0);
  end
endmodule
