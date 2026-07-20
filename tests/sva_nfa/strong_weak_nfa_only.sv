// M9-NFA stage C.2: strong/weak sequence property strength (IEEE
// 1800-2017 16.12.2). `strong(seq)' requires every (gated) attempt to
// complete: an attempt still pending at end of simulation is a FAILURE.
// `weak(seq)' (and a bare sequence) is the default: a pending attempt
// neither fails nor succeeds (an informational end-of-sim note only).
// Automaton-only (the legacy engine has no end-of-sim obligation for a
// bare sequence and sorries `strong'); the nfa_only gate compares
// flag-on output against the gold, and the flag-off compile must sorry.
//
// req@0 is answered by ack@2 (obligation met, no report). req@4 is
// never answered: the STRONG copy fails at end of simulation; the WEAK
// copy emits only the pending note.
module strong_weak_t;
  logic clk=0, req=0, ack=0;
  always #5 clk = ~clk;

  ps: assert property (@(posedge clk) req |-> strong(##[1:$] ack));
  pw: assert property (@(posedge clk) req |-> weak(##[1:$] ack));

  initial begin
    @(negedge clk) req=1;      // 0  req#1
    @(negedge clk) req=0;      // 1
    @(negedge clk) ack=1;      // 2  ack for req#1 -> obligation met
    @(negedge clk) ack=0;      // 3
    @(negedge clk) req=1;      // 4  req#2 -- never answered
    @(negedge clk) req=0;      // 5
    repeat(3) @(negedge clk);
    $display("strong_weak_done");
    $finish(0);
  end
endmodule
