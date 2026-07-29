// RANDOM-DIST regression (campaign 6 wave 2): IEEE 1800-2017 18.4.2 --
// `randc` combined with an explicit constraint used to silently drop
// cycle-completeness. The pre-existing cyclic-bitmap pre-fill picked a
// value BEFORE the constraint solver ran, then the solver (which also
// decides this property, since a constraint mentions it) overwrote that
// pick with whatever feasible value its (biased) diversity objective
// preferred -- with no cycle tracking at all on the solver's side, and
// the pre-fill's own mark left stale (recording a value that was never
// actually the one emitted).
//
// What "cycling" actually guarantees here (confirmed against this
// implementation's UNCONSTRAINED randc, which this fix does not touch):
// no repeat within one pass through the K feasible values, but the reset
// at the end of a pass is not itself derangement-safe, so the LAST pick
// of one pass and the FIRST pick of the next CAN coincide -- i.e. the
// adjacent-repeat rate over a long run should sit close to the
// "boundary-only" rate of about 1/K per K calls (about N/K^2 over N
// calls), not zero. That is exactly the healthy baseline measured here
// for a plain (unconstrained) randc of the same period, so this test
// compares the CONSTRAINED randc's measured rate against that same
// healthy band rather than demanding an unrealistic zero.
//
// Confirmed measurements motivating the thresholds below (fixed process-
// global RNG stream, so these reproduce run to run): constrained randc
// with a 3-value feasible set (period 3) over 3000 calls -- healthy/
// fixed implementation ~340/3000 (~11%, matching the ~1/9 theoretical
// boundary rate); pre-fix ~671/3000 (~22%, no real cycling). A 4-value
// feasible set (period 4) over 4000 calls -- fixed ~282/4000 (~7%,
// matching ~1/16 theoretical); pre-fix ~1178/4000 (~29%, close to flat
// per-call randomness with no cycling at all). The thresholds below sit
// roughly midway between the healthy and broken measurements.
module main;
  bit failed = 0;
  task check(string label, bit ok);
    if (!ok) begin
      $display("FAILED -- %0s", label);
      failed = 1;
    end
  endtask

  // Small feasible set (3 of 4 encodings of a 2-bit field).
  class C1;
    randc bit [1:0] x;
    constraint c { x inside {[0:2]}; }
  endclass

  // Gapped named-value feasible set via `inside` on a wider field (4
  // legal values out of 16 encodings).
  class C2;
    randc bit [3:0] x;
    constraint c { x inside {1, 3, 5, 12}; }
  endclass

  initial begin
    automatic C1 c1 = new;
    automatic C2 c2 = new;
    int rc;

    // --- C1: period 3 --------------------------------------------------
    begin
      int n = 1500;
      int bad = 0;
      int adjacent_repeats = 0;
      int prev, cur;
      rc = c1.randomize();
      if (rc != 1 || c1.x > 2) bad++;
      prev = c1.x;
      for (int i = 0; i < n; i++) begin
        rc = c1.randomize();
        if (rc != 1 || c1.x > 2) bad++;
        cur = c1.x;
        if (cur == prev) adjacent_repeats++;
        prev = cur;
      end
      check("randc-c1-solves-in-range", bad == 0);
      // Healthy ~11% (theoretical ~1/9); pre-fix measured ~22%. 18%
      // sits between the two, comfortably above sampling noise on the
      // healthy side and comfortably below the broken measurement.
      check("randc-c1-cycles",
            adjacent_repeats < (n * 18) / 100);
    end

    // --- C2: period 4 --------------------------------------------------
    begin
      int n = 2000;
      int bad = 0;
      int adjacent_repeats = 0;
      int prev, cur;
      rc = c2.randomize();
      if (rc != 1) bad++;
      else if (!(c2.x==1 || c2.x==3 || c2.x==5 || c2.x==12)) bad++;
      prev = c2.x;
      for (int i = 0; i < n; i++) begin
        rc = c2.randomize();
        if (rc != 1) bad++;
        else if (!(c2.x==1 || c2.x==3 || c2.x==5 || c2.x==12)) bad++;
        cur = c2.x;
        if (cur == prev) adjacent_repeats++;
        prev = cur;
      end
      check("randc-c2-solves-in-range", bad == 0);
      // Healthy ~7% (theoretical ~1/16); pre-fix measured ~29%. 15%
      // sits between the two with the same margin logic as C1 above.
      check("randc-c2-cycles",
            adjacent_repeats < (n * 15) / 100);
    end

    if (!failed) $display("PASSED");
  end
endmodule
