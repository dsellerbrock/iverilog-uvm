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

    // T6: tight range via `inside` operator — fast path detects
    // `arg inside [lo:hi]` and folds into min/max bounds.
    for (int i = 0; i < 32; i++) begin
      x = 0;
      std::randomize(x) with { x inside {[5:9]}; };
      if (x < 5 || x > 9)
	$fatal(1, "FAIL/T6 iter=%0d: x=%0d outside [5,9]", i, x);
    end

    // T7: single-element range — `inside {[42:42]}` collapses to ==
    for (int i = 0; i < 8; i++) begin
      x = 0;
      std::randomize(x) with { x inside {[42:42]}; };
      if (x !== 42)
	$fatal(1, "FAIL/T7 iter=%0d: x=%0d expected 42", i, x);
    end

    // T8: multi-value enum — `inside {1, 5, 10, 100}` exercises the
    // case-statement uniform-pick lowering.  Verify all returned
    // values are in the set.
    begin
      bit hit_1 = 0, hit_5 = 0, hit_10 = 0, hit_100 = 0;
      for (int i = 0; i < 64; i++) begin
	x = 0;
	std::randomize(x) with { x inside {1, 5, 10, 100}; };
	case (x)
	  1:   hit_1 = 1;
	  5:   hit_5 = 1;
	  10:  hit_10 = 1;
	  100: hit_100 = 1;
	  default:
	    $fatal(1, "FAIL/T8 iter=%0d: x=%0d not in {1,5,10,100}", i, x);
	endcase
      end
      if (!hit_1 || !hit_5 || !hit_10 || !hit_100)
	$fatal(1, "FAIL/T8: missing values 1=%0d 5=%0d 10=%0d 100=%0d",
	       hit_1, hit_5, hit_10, hit_100);
    end

    $display("PASS: std::randomize with-clause constraint enforcement");
    $finish;
  end
endmodule
