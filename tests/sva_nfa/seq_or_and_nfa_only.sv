// M9-NFA stage B.1: sequence `or' / `and' — regular-language
// combinators with no legacy lowering (previously raw syntax errors;
// now a loud sorry without IVL_SVA_NFA=1). `or' is the union
// automaton; `and' is the product with done-idling, so the match ends
// with the LATER side (IEEE 1800-2017 16.9.5/16.9.7). Plain asserts
// attempt every tick, so idle ticks fail — the gold pins the complete
// stream, hand-verified.
module seq_or_and_nfa_only;
  logic clk = 0, a = 0, b = 0, c = 0, d = 0;
  always #5 clk = ~clk;

  s1: assert property (@(posedge clk) (a ##1 b) or (c ##2 d))
        $display("s1 PASS at %0t", $time);
        else $display("s1 FAIL at %0t", $time);
  s2: assert property (@(posedge clk) (a ##1 b) and (c ##2 d))
        $display("s2 PASS at %0t", $time);
        else $display("s2 FAIL at %0t", $time);

  initial begin
    @(negedge clk) a = 1; c = 1;         // both branches start @15
    @(negedge clk) a = 0; c = 0; b = 1;  // b@25: or matches @25
    @(negedge clk) b = 0; d = 1;         // d@35: and matches @35 (later side)
    @(negedge clk) d = 0;
    @(negedge clk) a = 1;                // a@55 alone: or via left @65; and dies @55
    @(negedge clk) a = 0; b = 1;         // b@65
    @(negedge clk) b = 0;
    repeat (2) @(negedge clk);
    $finish(0);
  end
endmodule
