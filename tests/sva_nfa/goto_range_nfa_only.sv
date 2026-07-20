// M9-NFA stage C.1: goto/nonconsecutive repetition — ranged, unbounded,
// and exact counts (IEEE 1800-2017 16.9.2). Automaton-only (legacy
// sorries; nfa_only gate compares flag-on against the gold).
//
// Trace: a@0; b#1@2 with c@3; b#2@4 with c@5.
//   `a ##1 b[->1:2] ##1 c'  — cover counts the shortest match once per
//       attempt (the same rule `a ##[1:n] b' and first_match follow), so
//       the length-1 match (b#1@2 -> c@3) is the counted one => 1.
//   `a ##1 b[->1:$] ##1 c'  — unbounded upper, shortest match => 1.
//   `a ##1 b[=2] ##1 c'     — exactly two b's then ##1 c@5 => 1.
// The longer path is still genuinely reachable: goto_range_nfa_only pins
// the counts; goto_nonconsec_nfa_only and the negative test pin the
// semantics and the flag-off rejection.
module goto_range_t;
  logic clk=0, a=0, b=0, c=0;
  always #5 clk = ~clk;

  gr: cover property (@(posedge clk) a ##1 b[->1:2] ##1 c);
  gu: cover property (@(posedge clk) a ##1 b[->1:$] ##1 c);
  e2: cover property (@(posedge clk) a ##1 b[=2] ##1 c);

  initial begin
    @(negedge clk) a=1;          // 0
    @(negedge clk) a=0; b=0;     // 1
    @(negedge clk) b=1;          // 2  b#1
    @(negedge clk) b=0; c=1;     // 3  c after b#1
    @(negedge clk) b=1; c=0;     // 4  b#2
    @(negedge clk) b=0; c=1;     // 5  c after b#2
    @(negedge clk) c=0;          // 6
    repeat(3) @(negedge clk);
    $display("range=%0d unbounded=%0d eq2=%0d",
             _ivl_sva0_cnt0, _ivl_sva1_cnt0, _ivl_sva2_cnt0);
    $finish(0);
  end
endmodule
