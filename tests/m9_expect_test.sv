// M9-frontier (Phase 3): `expect (property) pass; else fail;' — the
// procedural blocking assertion (IEEE 1800-2017 16.17). Lowered to
// procedural clock-waits + boolean checks; the executing process blocks
// until a single attempt of the fixed-length boolean sequence completes,
// then runs the pass action on a match or the else action on a failure.
//
// Self-checking: each scenario adds 1 to `score' on the CORRECT branch
// and 100 on the wrong one, so score == 3 iff all three behaved exactly.
// clk posedge @ 5,15,25...
module m9_expect_test;
  logic clk=0;
  logic a1=0,b1=0, a2=0,b2=0, a3=0,b3=0;
  integer score = 0;
  always #5 clk = ~clk;

  // Scenario 1 — MATCH: a1@tick1, b1@tick2 -> pass branch.
  initial begin #1 a1=1; #10 b1=1; end
  initial expect (@(posedge clk) a1 ##1 b1) score = score + 1;
            else score = score + 100;

  // Scenario 2 — FAIL at the 2nd tick: a1 holds, b2 never -> else branch.
  initial begin #1 a2=1; end
  initial expect (@(posedge clk) a2 ##1 b2) score = score + 100;
            else score = score + 1;

  // Scenario 3 — FAIL at the 1st tick: a3 never high -> else branch.
  initial expect (@(posedge clk) a3 ##1 b3) score = score + 100;
            else score = score + 1;

  initial begin
    #60;
    if (score == 3)
      $display("m9_expect_test PASS (score=%0d)", score);
    else
      $display("m9_expect_test MISMATCH (score=%0d, expected 3)", score);
    $finish(0);
  end
endmodule
