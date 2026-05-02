// Phase 63b/B8 (real impl): std::randomize(args) [with {...}];
// must actually assign random values to the args, not silently
// no-op.
//
// Pre-fix (commit 27e565fff): the call returned 1 (success) but
// the args retained their initial values (typically 0).  Tests
// that verified randomness silently false-passed.
//
// Real impl: lower the statement to a block of `arg = $random;`
// assignments at parse time.  The with-clause constraints are still
// dropped (no Z3 routing yet) but the args genuinely receive
// random values.  Test verifies non-zero output across multiple
// calls (high-confidence proxy for randomness).
`timescale 1ns/1ps

module top;
  initial begin
    int x;
    int y;
    int hits = 0;
    int success;

    // T1: single-arg statement form with no with-clause
    success = 0;
    for (int i = 0; i < 16; i++) begin
      x = 0;
      void'(std::randomize(x));
      if (x !== 0) success++;
    end
    if (success < 12)
      $fatal(1, "FAIL/T1: expected at least 12/16 non-zero, got %0d", success);

    // T2: single-arg statement form with with-clause (constraints dropped
    // in this iteration; verify args still get randomized)
    success = 0;
    for (int i = 0; i < 16; i++) begin
      x = 0;
      std::randomize(x) with { x > 0; };
      if (x !== 0) success++;
    end
    if (success < 12)
      $fatal(1, "FAIL/T2: expected at least 12/16 non-zero, got %0d", success);

    // T3: multi-arg statement form
    success = 0;
    for (int i = 0; i < 16; i++) begin
      x = 0; y = 0;
      std::randomize(x, y);
      if (x !== 0 && y !== 0) success++;
    end
    if (success < 8)
      $fatal(1, "FAIL/T3: expected at least 8/16 both non-zero, got %0d", success);

    $display("PASS: std::randomize lowers to per-arg $random assignment");
    $finish;
  end
endmodule
