// M9-NFA stage C.1: goto `[->m:n]` and nonconsecutive `[=m:n]` repetition
// (IEEE 1800-2017 16.9.2) are lowered only by the automaton engine
// (IVL_SVA_NFA=1), which builds a counting wait-loop. The legacy linear
// engine has no such construct; with the flag off it must reject the
// assertion with a loud sorry rather than silently drop it. (Flag-on
// behaviour is pinned by tests/sva_nfa/goto_*_nfa_only.sv.)
module sva_goto_nonconsec;
  logic clk=0, a=0, b=0, c=0;
  always #5 clk=~clk;
  s: assert property (@(posedge clk) a |-> b[->2] ##1 c);
  initial begin repeat(3) @(negedge clk); $finish(0); end
endmodule
