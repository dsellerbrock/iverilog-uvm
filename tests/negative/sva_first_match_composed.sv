// M9-NFA: a composed multi-length `first_match' (the shortest-match cut
// changes which match continues) must be a LOUD sorry on the LEGACY
// engine, not a silent over-match. The automaton engine (IVL_SVA_NFA=1)
// now lowers it exactly by expanding into a disjoint `or' of fixed-
// length branches (see tests/sva_nfa/first_match_composed_nfa_only.sv);
// this file pins the flag-off rejection.
module sva_first_match_composed;
  logic clk=0, a=0, b=0, c=0;
  always #5 clk=~clk;
  s: assert property (@(posedge clk) first_match(a ##[1:2] b) ##1 c);
  initial begin repeat(3) @(negedge clk); $finish(0); end
endmodule
