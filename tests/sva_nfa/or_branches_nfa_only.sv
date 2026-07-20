// M9-NFA regression for the fold-epsilon fix: each `or` branch must be
// independently reachable from the start. The stimulus fires ONLY the
// second branch of each property (the first operand's leading boolean
// never rises), so a match proves the second branch is live — the
// symptom the earlier predecessor-duplication fold got wrong (it
// orphaned every branch but the first). NFA-only (legacy sorries).
module or_branches_nfa_only;
  logic clk = 0, a=0,b=0,c=0,d=0;
  always #5 clk = ~clk;

  // second branch only: a never rises, so only (c ##1 d) can match
  s2: cover property (@(posedge clk) (a ##1 b) or (c ##1 d));   // inst 0
  // first branch only: d never rises, so only (a ##1 b) can match
  s1: cover property (@(posedge clk) (a ##1 b) or (c ##1 d));   // inst 1

  initial begin
    // Phase 1: drive c##1d (second branch of s2 / s1)
    @(negedge clk) c=1;
    @(negedge clk) c=0; d=1;      // (c##1d) matches -> both cover +1
    @(negedge clk) d=0;
    @(negedge clk);
    // Phase 2: drive a##1b (first branch)
    @(negedge clk) a=1;
    @(negedge clk) a=0; b=1;      // (a##1b) matches -> both cover +1
    @(negedge clk) b=0;
    @(negedge clk);
    $display("s2=%0d s1=%0d (each expect 2)", _ivl_sva0_cnt0, _ivl_sva1_cnt0);
    $finish(0);
  end
endmodule
