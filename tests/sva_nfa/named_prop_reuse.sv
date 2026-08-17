// C5-1: a named property instantiated by MORE THAN ONE assertion
// (IEEE 1800-2017 16.12 — a property declaration may be instantiated
// any number of times). Pre-fix, instantiation CONSUMED the stored
// declaration: the first `assert property (comp_p)` worked and the
// second resolved `comp_p` as a nonexistent boolean signal, drew only
// a bind warning, and never fired PASS or FAIL — a silently-dead
// assertion. The fix deep-clones the declaration per instantiation.
// Both instances must show fails=1 passes=1 on the same stimulus.
// NFA-EXPECT-FALLBACK
module named_prop_reuse;
  logic clk = 0, a = 0, b = 0;
  always #5 clk = ~clk;
  default clocking cb @(posedge clk); endclocking

  property comp_p;
    a |=> b;
  endproperty

  int first_fails = 0, second_fails = 0;
  int first_passes = 0, second_passes = 0;

  first_use: assert property (comp_p)
        first_passes++;
        else first_fails++;
  second_use: assert property (comp_p)
        second_passes++;
        else second_fails++;

  initial begin
    // MUST-FIRE: a=1 then b=0 next cycle -> both instances FAIL once.
    @(negedge clk) a = 1;          // a@15
    @(negedge clk) a = 0;          // b@25 = 0: both FAIL@25
    @(negedge clk) b = 0;
    // MUST-NOT-FIRE: a=1 then b=1 next cycle -> both PASS once.
    @(negedge clk) a = 1;          // a@45
    @(negedge clk) a = 0; b = 1;   // b@55 = 1: both PASS@55
    @(negedge clk) b = 0;
    @(negedge clk);
    $display("first_use : fails=%0d passes=%0d (expect fails=1 passes=1)",
             first_fails, first_passes);
    $display("second_use: fails=%0d passes=%0d (expect fails=1 passes=1)",
             second_fails, second_passes);
    $finish(0);
  end
endmodule
