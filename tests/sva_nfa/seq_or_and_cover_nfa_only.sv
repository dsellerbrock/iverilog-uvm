// M9-NFA stage B.1: cover of sequence `or' / `and' — counts matched
// attempts only (idle ticks are silent), so the counters give a clean
// semantic check: or covers the @15 attempt (left branch @25) and the
// @55 attempt (left branch @65) = 2; and covers only the @15 attempt
// (both branches, ends @35 with the later side) = 1.
module seq_or_and_cover_nfa_only;
  logic clk = 0, a = 0, b = 0, c = 0, d = 0;
  always #5 clk = ~clk;

  c1: cover property (@(posedge clk) (a ##1 b) or (c ##2 d));   // inst 0
  c2: cover property (@(posedge clk) (a ##1 b) and (c ##2 d));  // inst 1

  initial begin
    @(negedge clk) a = 1; c = 1;
    @(negedge clk) a = 0; c = 0; b = 1;
    @(negedge clk) b = 0; d = 1;
    @(negedge clk) d = 0;
    @(negedge clk) a = 1;                // left-only attempt
    @(negedge clk) a = 0; b = 1;
    @(negedge clk) b = 0;
    repeat (2) @(negedge clk);
    $display("or count=%0d and count=%0d", _ivl_sva0_cnt0, _ivl_sva1_cnt0);
    $finish(0);
  end
endmodule
