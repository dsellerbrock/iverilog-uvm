// M11-1: covergroup bin semantics (IEEE1800-2017 clause 19).
// Every check pins a behavior the pre-M11 implementation silently
// broke or dropped: multi-range bins (were AND'd — never hit),
// arrayed bins (collapsed), with-filters (ranges deleted), wildcard/
// default bins (dropped via error recovery), ignore carve-out
// (ignored values still counted), iff guards, auto bins, at_least.
module m11_coverage_bins_test;

  int pass_count = 0;
  int fail_count = 0;

  task check(input string name, input bit ok);
    if (ok) pass_count++;
    else begin
      fail_count++;
      $display("FAIL: %s", name);
    end
  endtask

  // --- multi-range OR + arrayed + with + wildcard + default ---
  class c1;
    int val;
    covergroup cg;
      cp: coverpoint val {
        bins two_ranges = {[0:3], [8:11]};     // one bin, OR of ranges
        bins spread[]   = {20, 22, 24};        // three bins, one per value
        bins halves[2]  = {[30:33]};           // two bins of two values
        bins evens      = {[40:47]} with (item % 2 == 0);
        bins others     = default;             // excluded from coverage
      }
    endgroup
    function new(); cg = new; endfunction
    function void go(int v); val = v; cg.sample(); endfunction
    function real cov(); return cg.get_inst_coverage(); endfunction
  endclass

  // --- ignore/illegal + iff guard ---
  class c2;
    int val;
    bit en;
    covergroup cg;
      cp: coverpoint val iff (en) {
        bins lo = {[0:7]};
        bins hi = {[8:15]};
        ignore_bins skip = {5, 6};
      }
    endgroup
    function new(); cg = new; en = 1; endfunction
    function void go(int v); val = v; cg.sample(); endfunction
    function real cov(); return cg.get_inst_coverage(); endfunction
  endclass

  // --- wildcard bins ---
  class c3;
    bit [3:0] val;
    covergroup cg;
      cp: coverpoint val {
        wildcard bins low_odd = {4'b0??1};  // 1,3,5,7
        bins others = default;
      }
    endgroup
    function new(); cg = new; endfunction
    function void go(bit [3:0] v); val = v; cg.sample(); endfunction
    function real cov(); return cg.get_inst_coverage(); endfunction
  endclass;

  // --- auto bins over a small type ---
  class c4;
    bit [2:0] val;
    covergroup cg;
      cp: coverpoint val;  // 8 auto bins
    endgroup
    function new(); cg = new; endfunction
    function void go(bit [2:0] v); val = v; cg.sample(); endfunction
    function real cov(); return cg.get_inst_coverage(); endfunction
  endclass

  // --- at_least option ---
  class c5;
    int val;
    covergroup cg;
      option.at_least = 2;
      cp: coverpoint val {
        bins a = {1};
        bins b = {2};
      }
    endgroup
    function new(); cg = new; endfunction
    function void go(int v); val = v; cg.sample(); endfunction
    function real cov(); return cg.get_inst_coverage(); endfunction
  endclass

  c1 o1;
  c2 o2;
  c3 o3;
  c4 o4;
  c5 o5;
  real r;
  int k;

  initial begin
    // c1: 8 countable bins (two_ranges, spread0..2, halves0..1, evens, ... )
    // evens keeps {40,42,44,46}. default excluded.
    o1 = new;
    o1.go(9);                     // two_ranges (second range!)
    r = o1.cov();
    check("multirange_or", r > 14.0 && r < 15.0); // 1/7 = 14.29

    o1.go(22);                    // spread[1] only
    r = o1.cov();
    check("arrayed_per_value", r > 28.0 && r < 29.0); // 2/7

    o1.go(30); o1.go(31);         // halves[0] covers {30,31}
    r = o1.cov();
    check("sized_array_chunk", r > 42.0 && r < 43.0); // 3/7

    o1.go(41);                    // odd: filtered OUT by with()
    r = o1.cov();
    check("with_filter_excludes", r > 42.0 && r < 43.0); // still 3/7
    o1.go(42);                    // even: kept by with()
    r = o1.cov();
    check("with_filter_includes", r > 57.0 && r < 57.5); // 4/7

    o1.go(20); o1.go(24);         // remaining spread bins
    o1.go(32);                    // halves[1]
    o1.go(0);                     // two_ranges again (already hit)
    r = o1.cov();
    check("all_value_bins", r == 100.0); // 7/7 (default not counted)

    // c2: ignore carve-out and iff guard
    o2 = new;
    o2.go(5);                     // ignored value: lo must NOT count
    r = o2.cov();
    check("ignore_carves_out", r == 0.0);
    o2.en = 0;
    o2.go(1);                     // guard off: not sampled
    r = o2.cov();
    check("iff_gates_sampling", r == 0.0);
    o2.en = 1;
    o2.go(1);                     // now lo counts
    r = o2.cov();
    check("iff_enables", r == 50.0);
    o2.go(12);
    r = o2.cov();
    check("full_after_guard", r == 100.0);

    // c3: wildcard 0??1 matches 1,3,5,7
    o3 = new;
    o3.go(4'b0011);               // 3: matches
    r = o3.cov();
    check("wildcard_match", r == 100.0); // 1 countable bin
    o3 = new;
    o3.go(4'b1001);               // 9: high bit 1 → no match
    r = o3.cov();
    check("wildcard_nomatch", r == 0.0);

    // c4: 8 auto bins for bit [2:0]
    o4 = new;
    for (k = 0; k < 8; k++) o4.go(k[2:0]);
    r = o4.cov();
    check("auto_bins_full", r == 100.0);
    o4 = new;
    o4.go(3'd2);
    r = o4.cov();
    check("auto_bins_partial", r == 12.5); // 1/8

    // c5: at_least = 2 — one hit is not enough
    o5 = new;
    o5.go(1);
    r = o5.cov();
    check("at_least_below", r == 0.0);
    o5.go(1);
    r = o5.cov();
    check("at_least_met", r == 50.0);
    o5.go(2); o5.go(2);
    r = o5.cov();
    check("at_least_full", r == 100.0);

    if (fail_count == 0)
      $display("M11 COVERAGE BINS TEST: PASS (%0d/%0d)", pass_count, pass_count);
    else
      $display("M11 COVERAGE BINS TEST: FAIL (%0d passed, %0d failed)",
               pass_count, fail_count);
    $finish(0);
  end
endmodule
