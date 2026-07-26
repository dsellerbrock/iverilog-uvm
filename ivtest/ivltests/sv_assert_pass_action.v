// IEEE 1800-2017 16.14.6: an assertion's action block has two halves,
// and the pass statement runs when the assertion SUCCEEDS.
//
// The temporal-operator lowering deleted the pass statement before it
// emitted anything, for every operator it handles -- `within', the
// `until' family, the liveness operators and the abort operators. So
//
//     assert property (b within (x ##1 x ##1 x)) hits++; else miss++;
//
// counted misses and never a hit. The verdicts themselves were right
// (tests/sva_nfa/within_* check those); it was only the success half of
// the action block that vanished, and it vanished without a word, which
// is why nothing caught it.
//
// `within' now runs its pass statement on the same mature-window
// condition its failure uses, so exactly one of the two fires per
// window. The operators whose obligation this lowering does not
// discharge cycle by cycle now REFUSE a pass statement out loud instead
// of dropping it; that half is covered by the negative suite.
//
// The stimulus is the one tests/sva_nfa/within_fixed uses, where the
// first x-run contains b and the later windows do not: one success,
// then failures.

module main;

  logic clk = 0, b = 0, x = 0;

  int wpass = 0, wfail = 0;
  int cpass = 0, cfail = 0;
  int fails = 0;

  always #5 clk = ~clk;

  // the operator that was dropping its pass statement
  w: assert property (@(posedge clk) b within (x ##1 x ##1 x))
        wpass++; else wfail++;

  // control: an ordinary implication, which always ran both halves
  c: assert property (@(posedge clk) x |-> ##1 x)
        cpass++; else cfail++;

  initial begin
    @(negedge clk) x = 1; b = 1;   // the x run starts, with b inside it
    @(negedge clk) x = 1; b = 0;
    @(negedge clk) x = 1;          // the run completes -> this window matches
    @(negedge clk) x = 0;
    repeat (3) @(negedge clk);

    if (wpass == 0) begin
      fails++;
      $display("FAILED -- `within' never ran its pass statement");
    end
    if (wfail == 0) begin
      fails++;
      $display("FAILED -- `within' stopped reporting failures");
    end
    if (cpass == 0 || cfail == 0) begin
      fails++;
      $display("FAILED -- the control assertion changed: pass=%0d fail=%0d",
               cpass, cfail);
    end

    if (fails == 0) $display("PASSED");
    $finish(0);
  end

endmodule
