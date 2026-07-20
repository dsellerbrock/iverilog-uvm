// M9-NFA: COMPOSED `first_match` (IEEE 1800-2017 16.9.9). A first_match
// whose variable-length inner sequence FEEDS A CONTINUATION cannot ride
// the transparent lowering: the cut (keep only the earliest match)
// changes which match the tail continues from, so transparency would
// silently OVER-match. The automaton engine expands it into a disjoint
// `or' of fixed-length branches -- branch k requires `!b' at every
// earlier window offset and `b' at offset k, so exactly the earliest
// match survives -- which is EXACT first_match semantics. The legacy
// engine has no sequence-tree IR and rejects this shape with a loud
// sorry (nfa_only gate: flag-off must sorry, flag-on matches the gold).
//
// Property: first_match(a ##[1:2] b) ##1 c
//   = (a ##1 b ##1 c)  or  (a ##1 !b ##1 b ##1 c)
//
// The count is 2, NOT 3: Phase A commits to the earliest match (b at
// offset 1) whose tail c is absent, so it must NOT fall through to the
// longer match (b at offset 2) whose tail c IS present. A transparent
// (over-matching) engine would wrongly report 3.
module first_match_composed_t;
  logic clk=0, a=0, b=0, c=0;
  always #5 clk = ~clk;

  f: cover property (@(posedge clk) first_match(a ##[1:2] b) ##1 c);

  task idle; repeat(4) @(negedge clk) {a,b,c}=0; endtask

  initial begin
    // Phase A: earliest match is b@offset1, but c is absent there; the
    // longer match b@offset2 has c. first_match commits to the earliest
    // -> this attempt must contribute 0 (a wrong engine adds 1).
    @(negedge clk) a=1;
    @(negedge clk) a=0; b=1;   // offset1: b present
    @(negedge clk) b=1;        // offset2: b present; c@offset1 == 0
    @(negedge clk) b=0; c=1;   // offset2's tail c
    @(negedge clk) c=0;
    idle;

    // Phase B: earliest match b@offset1, c present one cycle later -> 1.
    @(negedge clk) a=1;
    @(negedge clk) a=0; b=1;
    @(negedge clk) b=0; c=1;
    @(negedge clk) c=0;
    idle;

    // Phase C: b@offset1 absent, so the earliest match is b@offset2;
    // its tail c is present -> 1.
    @(negedge clk) a=1;
    @(negedge clk) a=0; b=0;
    @(negedge clk) b=1;
    @(negedge clk) b=0; c=1;
    @(negedge clk) c=0;
    idle;

    $display("composed_first_match_count=%0d", _ivl_sva0_cnt0);
    $finish(0);
  end
endmodule
