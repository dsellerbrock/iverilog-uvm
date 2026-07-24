// Deterministic: one thread, no inter-process race. At t=5 the Active
// region does a=1 THEN clk=1. IEEE 1800 16.5.1: the assertion clocked on
// posedge clk samples the PREPONED value of a (=0), so the antecedent is
// false and the attempt is vacuous -> fails must be 0.
module top;
  bit clk = 0, a = 0, b = 0;
  int fails = 0, passes = 0;
  ap: assert property (@(posedge clk) a |-> b) passes++; else fails++;
  initial begin
    #5  a = 1;      // Active region, same slot as the edge below
        clk = 1;    // posedge at t=5
    #5  clk = 0;
    #5  $display("fails=%0d passes=%0d", fails, passes);
        if (fails == 0) $display("PASS m6b4_det (preponed sampling)");
        else            $display("FAIL m6b4_det (Active-region value sampled)");
        $finish(0);
  end
endmodule
