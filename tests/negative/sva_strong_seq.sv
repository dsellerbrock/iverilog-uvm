// M9-NFA stage C.2: a `strong(seq)' sequence property (IEEE 1800-2017
// 16.12.2) carries an end-of-simulation obligation the legacy engine
// cannot express — it would silently lower `strong(seq)' as a plain
// (weak) sequence, dropping the obligation. With the automaton engine
// off it must reject the assertion with a loud sorry. (Flag-on behaviour
// is pinned by tests/sva_nfa/strong_weak_nfa_only.sv. `weak(seq)' is the
// default and lowers on either engine, so it is not rejected.)
module sva_strong_seq;
  logic clk=0, req=0, ack=0;
  always #5 clk=~clk;
  s: assert property (@(posedge clk) req |-> strong(##[1:$] ack));
  initial begin repeat(3) @(negedge clk); $finish(0); end
endmodule
