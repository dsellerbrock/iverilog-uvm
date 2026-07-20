// M9-NFA stage C.1: SVA goto `[->` and nonconsecutive `[=` repetition of
// a boolean (IEEE 1800-2017 16.9.2). These are automaton-only: the legacy
// engine has no counting wait-loop and rejects them with a loud sorry
// (nfa_only gate: flag-off must sorry, flag-on matches the gold).
//
// The discriminator is the end-of-match rule. GOTO `b[->1]' ends the
// match ON the occurrence, so `a ##1 b[->1] ##1 c' requires c exactly one
// cycle after the first b. NONCONSEC `b[=1]' may extend the match past
// the last b with non-b cycles, so `a ##1 b[=1] ##1 c' also accepts a c
// that arrives after a trailing !b.
//
// Trace: a@0, first b@2, !c@3 (the goto tail fails here), c@4.
//   goto:      first b@2 -> needs c@3 -> ABSENT -> 0 matches.
//   nonconsec: first b@2, trailing !b@3, then ##1 c@4 -> 1 match.
module goto_nonconsec_t;
  logic clk=0, a=0, b=0, c=0;
  always #5 clk = ~clk;

  gg: cover property (@(posedge clk) a ##1 b[->1] ##1 c);
  ee: cover property (@(posedge clk) a ##1 b[=1] ##1 c);

  initial begin
    @(negedge clk) a=1;          // 0
    @(negedge clk) a=0; b=0;     // 1  !b
    @(negedge clk) b=1;          // 2  first b
    @(negedge clk) b=0; c=0;     // 3  !c  -> goto tail fails
    @(negedge clk) c=1;          // 4  c
    @(negedge clk) c=0;          // 5
    repeat(3) @(negedge clk);
    $display("goto=%0d nonconsec=%0d", _ivl_sva0_cnt0, _ivl_sva1_cnt0);
    $finish(0);
  end
endmodule
