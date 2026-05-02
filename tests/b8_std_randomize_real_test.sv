// Phase 63b/B8 (gap close): std::randomize(args) [with {...}];
// must actually assign random values to the args satisfying the
// with-clause constraint, not silently drop it.
//
// Real impl: lower the statement to a retry loop at parse time:
//   repeat (256) begin args=$random; if (constraints) break; end
// 256 retries empirically covers small-domain constraints.
//
// Coverage:
//   T1 : void'(std::randomize(x))    — no constraint
//   T2 : with { x > 0; }              — single constraint
//   T3 : multi-arg with no constraint
//   T4 : with { x > 0; x < 16; }     — bounded range, must converge
//   T5 : with { x inside {[10:20]}; } — TODO: inside operator
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

    // T2: with-clause `x > 0` must be enforced — every iteration
    // produces x > 0
    for (int i = 0; i < 32; i++) begin
      x = 0;
      std::randomize(x) with { x > 0; };
      if (x <= 0)
	$fatal(1, "FAIL/T2 iter=%0d: x=%0d violates x>0", i, x);
    end

    // T3: multi-arg statement form, no constraint
    success = 0;
    for (int i = 0; i < 16; i++) begin
      x = 0; y = 0;
      std::randomize(x, y);
      if (x !== 0 && y !== 0) success++;
    end
    if (success < 8)
      $fatal(1, "FAIL/T3: expected at least 8/16 both non-zero, got %0d", success);

    // T4: tight range `x > 0 && x < 16` — must use $urandom_range
    // fast path detection (retry loop alone wouldn't converge in
    // any reasonable number of tries for this range size)
    for (int i = 0; i < 32; i++) begin
      x = 0;
      std::randomize(x) with { x > 0; x < 16; };
      if (x <= 0 || x >= 16)
	$fatal(1, "FAIL/T4 iter=%0d: x=%0d outside (0,16)", i, x);
    end

    // T4b: signed `x >= -10 && x <= 10`
    for (int i = 0; i < 32; i++) begin
      x = 0;
      std::randomize(x) with { x >= -10; x <= 10; };
      if (x < -10 || x > 10)
	$fatal(1, "FAIL/T4b iter=%0d: x=%0d outside [-10,10]", i, x);
    end

    // T5: multi-arg with-clause
    for (int i = 0; i < 16; i++) begin
      x = 0; y = 0;
      std::randomize(x, y) with { x > 0; y > 0; };
      if (x <= 0)
	$fatal(1, "FAIL/T5: x=%0d not >0", x);
      if (y <= 0)
	$fatal(1, "FAIL/T5: y=%0d not >0", y);
    end

    $display("PASS: std::randomize with-clause constraint enforcement");
    $finish;
  end
endmodule
