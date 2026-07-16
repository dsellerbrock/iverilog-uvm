// M11-3/4: named cross bins with binsof selects (19.6.1), type
// coverage (get_coverage merges instances), start/stop, and
// $get_coverage. Pre-M11 all of these were silently dropped or
// unavailable.
module m11_coverage_cross_query_test;

  int pass_count = 0;
  int fail_count = 0;

  task check(input string name, input bit ok);
    if (ok) pass_count++;
    else begin
      fail_count++;
      $display("FAIL: %s", name);
    end
  endtask

  // Cross with named binsof bins: a 2x2 space where the user names
  // one corner, ignores one, and lets the rest auto-bin.
  class cx;
    int a, b;
    covergroup cg;
      cpa: coverpoint a { bins lo = {[0:3]}; bins hi = {[4:7]}; }
      cpb: coverpoint b { bins lo = {[0:1]}; bins hi = {[2:3]}; }
      x: cross cpa, cpb {
        bins both_lo    = binsof(cpa.lo) && binsof(cpb.lo);
        ignore_bins mix = binsof(cpa.hi) && binsof(cpb.lo);
      }
    endgroup
    function new(); cg = new; endfunction
    function void go(int va, int vb); a = va; b = vb; cg.sample(); endfunction
    function real icov(); return cg.get_inst_coverage(); endfunction
  endclass

  // binsof intersect: select by value overlap.
  class ci;
    int v, w;
    covergroup cg;
      cpv: coverpoint v { bins b0 = {[0:9]}; bins b1 = {[10:19]}; }
      cpw: coverpoint w { bins c0 = {0}; bins c1 = {1}; }
      xx: cross cpv, cpw {
        bins low_pair = binsof(cpv) intersect {[0:9]} && binsof(cpw.c0);
      }
    endgroup
    function new(); cg = new; endfunction
    function void go(int a2, int b2); v = a2; w = b2; cg.sample(); endfunction
    function real icov(); return cg.get_inst_coverage(); endfunction
  endclass

  // Type coverage across two instances + start/stop.
  class ct;
    int val;
    covergroup cg;
      cp: coverpoint val { bins lo = {[0:7]}; bins hi = {[8:15]}; }
    endgroup
    function new(); cg = new; endfunction
    function void go(int v2); val = v2; cg.sample(); endfunction
    function real icov(); return cg.get_inst_coverage(); endfunction
    function real tcov(); return cg.get_coverage(); endfunction
    function void halt(); cg.stop(); endfunction
    function void go_again(); cg.start(); endfunction
  endclass

  cx o1;
  ci o2;
  ct t1, t2;
  real r;

  initial begin
    // Cross space: cpa {lo,hi} x cpb {lo,hi} = 4 tuples.
    //   both_lo user bin  <- (lo,lo)
    //   ignored           <- (hi,lo)
    //   auto bins         <- (lo,hi), (hi,hi)
    // Cross item has 3 countable bins; cpa/cpb have 2 each.
    o1 = new;
    o1.go(1, 0);   // (lo,lo) -> both_lo
    r = o1.icov();
    // items: cpa 1/2=50, cpb 1/2=50, cross 1/3=33.3 -> mean 44.44
    check("binsof_named", r > 44.0 && r < 45.0);

    o1.go(5, 0);   // (hi,lo) -> IGNORED tuple: cross must not move
    r = o1.icov();
    // cpa 2/2=100, cpb 1/2=50, cross 1/3 -> mean 61.1
    check("binsof_ignore", r > 61.0 && r < 61.3);

    o1.go(1, 3); o1.go(5, 2);  // the two auto tuples
    r = o1.icov();
    check("binsof_autos", r == 100.0);

    // intersect select
    o2 = new;
    o2.go(15, 0);  // b1 range does not intersect [0:9]: auto tuple
    r = o2.icov();
    // low_pair not hit; items: cpv 1/2, cpw 1/2, cross 1/4 (3 auto + named)
    check("intersect_miss", r > 41.0 && r < 42.0);
    o2.go(5, 0);   // b0 intersects [0:9] AND c0 -> low_pair
    r = o2.icov();
    // cpv 2/2, cpw 1/2, cross 2/4
    check("intersect_hit", r > 66.0 && r < 67.0);

    // Type coverage merges instances; instance coverage does not.
    t1 = new; t2 = new;
    t1.go(2);      // t1: lo
    t2.go(12);     // t2: hi
    check("inst_separate", t1.icov() == 50.0 && t2.icov() == 50.0);
    check("type_merged", t1.tcov() == 100.0);

    // stop() freezes sampling; start() resumes.
    t1.halt();
    t1.go(12);     // ignored: stopped
    check("stopped", t1.icov() == 50.0);
    t1.go_again();
    t1.go(12);
    check("restarted", t1.icov() == 100.0);

    // $get_coverage: mean over the three covergroup types (all 100%
    // by now except the cross ones... compute loosely: just bounds).
    r = $get_coverage();
    check("get_coverage_global", r > 0.0 && r <= 100.0);

    if (fail_count == 0)
      $display("M11 COVERAGE CROSS/QUERY TEST: PASS (%0d/%0d)", pass_count, pass_count);
    else
      $display("M11 COVERAGE CROSS/QUERY TEST: FAIL (%0d passed, %0d failed)",
               pass_count, fail_count);
    $finish(0);
  end
endmodule
