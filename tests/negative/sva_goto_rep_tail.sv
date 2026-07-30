// NEG-LEGACY-ONLY
// C5-2 wave 3: a tail repetition riding a goto/nonconsecutive step --
// `(b[->1])[*1:2]' -- is attached by pform_sva_repeat AFTER the goto
// step is built, and the automaton construction returned before the
// tail-repetition code ever ran. The tail was therefore SILENTLY
// DROPPED: the automaton came out byte-identical to `x ##1 b[->1]
// ##1 c' and legal matches of the second copy went missing with no
// diagnostic (IEEE 1800-2017 16.9.2 makes `(s)[*1:2]' equivalent to
// `s or (s ##1 s)'). Until the tail is actually built, the shape must
// be refused loudly rather than answered wrongly.
module sva_goto_rep_tail;
  logic clk=0, x=0, b=0, c=0;
  always #5 clk=~clk;
  cv: cover property (@(posedge clk) x ##1 (b[->1])[*1:2] ##1 c);
  initial begin repeat(3) @(negedge clk); $finish(0); end
endmodule
