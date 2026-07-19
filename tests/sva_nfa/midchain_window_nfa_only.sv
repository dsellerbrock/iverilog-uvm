// M9-NFA stage A win: mid-chain ##[m:n] window — the legacy engine
// sorries ("range only supported as the final step"); the automaton
// engine lowers it exactly. Verdicts checked against a hand-computed
// gold trace.
module midchain_window_nfa_only;
  logic clk = 0, a = 0, b = 0, c = 0;
  always #5 clk = ~clk;

  mw: assert property (@(posedge clk) a |-> ##[1:2] b ##1 c)
        $display("MW PASS at %0t", $time);
        else $display("MW FAIL at %0t", $time);

  initial begin
    @(negedge clk) a = 1;            // a@15: b@25 or b@35
    @(negedge clk) a = 0;
    @(negedge clk) b = 1;            // b@35 (2nd slot)
    @(negedge clk) b = 0; c = 1;     // c@45: PASS@45
    @(negedge clk) c = 0;
    @(negedge clk) a = 1;            // a@65: b@75 or b@85
    @(negedge clk) a = 0; b = 1;     // b@75 (1st slot)
    @(negedge clk) b = 0;            // c@85=0 kills 1st; b@85=0 kills 2nd: FAIL@85
    @(negedge clk);
    @(negedge clk);
    $finish(0);
  end
endmodule
