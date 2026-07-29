// RANDOM-DIST regression (campaign 6 wave 2): statistical checks for
// constrained-rand distribution shapes that were confirmed silently
// biased.
//
//  - IEEE 1800-2017 18.4.2: a non-power-of-two `inside` domain used to
//    come back badly non-uniform (Z3_optimize_minimize(bvxor(prop,
//    random_target)) only samples uniformly when the feasible set is
//    closed under XOR with a random target -- true for a full power-of-
//    two range, false otherwise). `x inside {[0:2]}` on a 2-bit field
//    measured ~249/252/499 over 1000 draws (value 2 nearly 1.5x hot);
//    `x inside {[0:99]}` on a 7-bit field measured the top of the range
//    (96-99) up to ~7x over-represented.
//  - IEEE 1800-2017 18.5.4: `dist` weights are a PROBABILITY
//    distribution over the branch values, not a preference for the
//    heaviest branch. `x dist {0:=1, [1:9]:/1, 10:=8}` (nominal
//    10%/10%/80%) measured as skewed as 0.5%/3.5%/96.1% in one run and
//    25%/23%/52% in another.
//
// This uses a simple chi-square-style goodness-of-fit statistic (sum of
// (observed-expected)^2/expected) against fixed thresholds: generous
// enough not to flake on ordinary sampling noise, but tight enough that
// the recorded defects above fail it by 3-10x (a few worked examples:
// the 249/252/499-over-1000 measurement scores ~123 against a uniform-
// thirds expectation of 333 each, and the 0.5/3.5/96.1%-over-2000
// measurement scores in the thousands against a 10/10/80 expectation --
// both threshold checks below are set at 30, i.e. comfortably below
// either failure and comfortably above the noise floor of a correct,
// exactly-uniform (or exactly-weighted) sampler).
module main;
  bit failed = 0;
  task check(string label, bit ok);
    if (!ok) begin
      $display("FAILED -- %0s", label);
      failed = 1;
    end
  endtask

  function automatic real chi2_(int obs[], real expv[], int n);
    real acc;
    acc = 0.0;
    for (int i = 0; i < n; i++)
      acc += (real'(obs[i]) - expv[i]) * (real'(obs[i]) - expv[i]) / expv[i];
    return acc;
  endfunction

  // 1. inside {[0:2]}: 3 of 4 encodings of a 2-bit field are legal.
  class C1;
    rand bit [1:0] x;
    constraint c { x inside {[0:2]}; }
  endclass

  // 2. inside {[0:99]}: 100 of 128 encodings of a 7-bit field.
  class C2;
    rand bit [6:0] x;
    constraint c { x inside {[0:99]}; }
  endclass

  // 3. Gapped named-value set (an enum with a hole plus an inside list
  // spanning it), matching the "gapped enum uniform over named values"
  // shape.
  typedef enum bit [3:0] {V_A=1, V_B=3, V_C=5, V_D=12} gap_e;
  class C3;
    rand gap_e x;
  endclass

  // 4. Full-range control: NO constraint at all, so this never reaches
  // the solver (the property is simply pre-filled and kept) -- must
  // stay exactly as uniform as it always was.
  class C4;
    rand bit [1:0] x;
  endclass

  // 5. dist with a single-value branch, a range branch (":/"), and a
  // heavy single-value branch: nominal 10% / 10% (spread over 9 values)
  // / 80%.
  class C5;
    rand bit [7:0] x;
    constraint c { x dist { 0 := 1, [1:9] :/ 1, 10 := 8 }; }
  endclass

  initial begin
    automatic C1 c1 = new;
    automatic C2 c2 = new;
    automatic C3 c3 = new;
    automatic C4 c4 = new;
    automatic C5 c5 = new;

    // --- 1: inside {[0:2]} -----------------------------------------
    begin
      int counts[4];
      real expv[3];
      int bad;
      int n = 2000;
      foreach (counts[i]) counts[i] = 0;
      bad = 0;
      for (int i = 0; i < n; i++) begin
        if (c1.randomize() != 1) bad++;
        counts[c1.x]++;
      end
      check("inside-0-2-solves", bad == 0);
      check("inside-0-2-legal-only", counts[3] == 0);
      expv[0] = n/3.0; expv[1] = n/3.0; expv[2] = n/3.0;
      check("inside-0-2-uniform", chi2_(counts, expv, 3) < 30.0);
    end

    // --- 2: inside {[0:99]} ------------------------------------------
    begin
      int counts[100];
      real expv[100];
      int bad, oor;
      int n = 2500;
      foreach (counts[i]) counts[i] = 0;
      bad = 0; oor = 0;
      for (int i = 0; i < n; i++) begin
        if (c2.randomize() != 1) bad++;
        if (c2.x > 99) oor++;
        else counts[c2.x]++;
      end
      check("inside-0-99-solves", bad == 0 && oor == 0);
      for (int i = 0; i < 100; i++) expv[i] = n/100.0;
      check("inside-0-99-flat", chi2_(counts, expv, 100) < 200.0);
      // The recorded defect made 96-99 up to ~7x hot (i.e. ~7*40=280 out
      // of 4000); a correct sampler's max bucket should stay well under
      // half that.
      begin
        int mx;
        mx = 0;
        foreach (counts[i]) if (counts[i] > mx) mx = counts[i];
        check("inside-0-99-no-hotspot", mx < (n/100)*3);
      end
    end

    // --- 3: gapped enum -----------------------------------------------
    begin
      int counts[4]; // indices: 0=V_A,1=V_B,2=V_C,3=V_D
      real expv[4];
      int bad;
      int n = 1500;
      foreach (counts[i]) counts[i] = 0;
      bad = 0;
      for (int i = 0; i < n; i++) begin
        if (c3.randomize() != 1) bad++;
        case (c3.x)
          V_A: counts[0]++;
          V_B: counts[1]++;
          V_C: counts[2]++;
          V_D: counts[3]++;
          default: bad++;
        endcase
      end
      check("gap-enum-solves", bad == 0);
      expv[0] = n/4.0; expv[1] = n/4.0; expv[2] = n/4.0; expv[3] = n/4.0;
      check("gap-enum-uniform", chi2_(counts, expv, 4) < 30.0);
    end

    // --- 4: full-range control (unchanged behavior) --------------------
    begin
      int counts[4];
      real expv[4];
      int n = 2000;
      foreach (counts[i]) counts[i] = 0;
      for (int i = 0; i < n; i++) begin
        void'(c4.randomize());
        counts[c4.x]++;
      end
      expv[0] = n/4.0; expv[1] = n/4.0; expv[2] = n/4.0; expv[3] = n/4.0;
      check("full-range-control-uniform", chi2_(counts, expv, 4) < 30.0);
    end

    // --- 5: dist 1:1:8 (0 :=1, [1:9]:/1, 10:=8) -------------------------
    begin
      int counts[11];
      real expv[11];
      int bad;
      int n = 2500;
      foreach (counts[i]) counts[i] = 0;
      bad = 0;
      for (int i = 0; i < n; i++) begin
        if (c5.randomize() != 1) bad++;
        if (c5.x <= 10) counts[c5.x]++;
        else bad++;
      end
      check("dist-solves", bad == 0);
      expv[0] = n * 0.10;
      for (int i = 1; i <= 9; i++) expv[i] = n * 0.10 / 9.0;
      expv[10] = n * 0.80;
      check("dist-weighted", chi2_(counts, expv, 11) < 40.0);
      // Aggregate sanity check on the three nominal buckets (0 / mid /
      // 10), independent of the per-value chi-square above.
      begin
        real p0, pmid, p10;
        int cmid;
        cmid = 0;
        for (int i = 1; i <= 9; i++) cmid += counts[i];
        p0 = 100.0 * counts[0] / n;
        pmid = 100.0 * cmid / n;
        p10 = 100.0 * counts[10] / n;
        check("dist-bucket-0-near-10pct", p0 > 5.0 && p0 < 16.0);
        check("dist-bucket-mid-near-10pct", pmid > 5.0 && pmid < 16.0);
        check("dist-bucket-10-near-80pct", p10 > 70.0 && p10 < 90.0);
      end
    end

    if (!failed) $display("PASSED");
  end
endmodule
