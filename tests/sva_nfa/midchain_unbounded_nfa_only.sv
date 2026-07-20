// M9-NFA stage A win: mid-chain ##[m:$] — the legacy engine sorries
// ("unbounded only supported as the final step"); the automaton
// engine lowers it with weak-eventually semantics: a looping
// obligation cannot fail in finite time and is reported as pending at
// end of simulation.
module midchain_unbounded_nfa_only;
  logic clk = 0, s = 0, b = 0, c = 0;
  always #5 clk = ~clk;

  mu: assert property (@(posedge clk) s |-> ##[1:$] b ##1 c)
        $display("MU PASS at %0t", $time);
        else $display("MU FAIL at %0t", $time);

  initial begin
    @(negedge clk) s = 1;            // s@15
    @(negedge clk) s = 0;
    repeat (3) @(negedge clk);       // waiting
    b = 1;                           // b@55
    @(negedge clk) b = 0; c = 1;     // c@65: PASS@65
    @(negedge clk) c = 0; s = 1;     // s@75
    @(negedge clk) s = 0; b = 1;     // b@85
    @(negedge clk) b = 0;            // c@95=0: branch dies; wait loop pends
    @(negedge clk);
    $finish(0);                      // pending note at EOS
  end
endmodule
