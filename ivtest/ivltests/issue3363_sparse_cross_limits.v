// Issue #3363 (IEEE 1800-2023 19.6, 19.6.1.1, 19.11.3): a cross over
// 65536 bins is counted exactly where the sparse mode of #3303 used to
// disable it or approximate it.
module top;
  int v, u; bit w;
  longint a, b;
  int failures = 0;

  // A fixed-size dimension of 20000000 bins with a binsof/intersect bin.
  covergroup cg_fixed;
    option.per_instance = 1;
    cp: coverpoint v { bins f[20000000] = {[0:39999999]}; }
    cq: coverpoint w;
    x: cross cp, cq { bins lo = binsof(cp) intersect {[100:200]}; }
  endgroup

  // A CrossQueueType set bin on a cross of 200000 bins.
  covergroup cg_set(int n);
    option.per_instance = 1;
    cp: coverpoint v { bins big[] = {[0:99999]}; }
    cq: coverpoint w;
    x: cross cp, cq {
      function CrossQueueType pair(int count);
        pair.push_back('{5, 0});
        if (count > 1) pair.push_back('{7, 1});
      endfunction
      bins s = pair(n);
    }
  endgroup

  // 2^80 tuples: more than a 64-bit count.
  covergroup cg_huge;
    option.per_instance = 1;
    ca: coverpoint a { bins x[] = {[0:64'd1099511627775]}; }
    cb: coverpoint b { bins y[] = {[0:64'd1099511627775]}; }
    x: cross ca, cb;
  endgroup

  // merge_instances: the type-level bins are the union of the instances'
  // bins by name, for disjoint, nested and dense instances alike.
  covergroup cg_union(int lo, int hi);
    type_option.merge_instances = 1;
    cp: coverpoint u { bins big[] = {[lo:hi]}; }
    cq: coverpoint w;
    x: cross cp, cq { ignore_bins ig = binsof(cp) intersect {[50000:60000]}; }
  endgroup

  task automatic check(string what, real got, real want);
    real tol = want * 1.0e-9;
    if (tol < 1.0e-12) tol = 1.0e-12;
    if (got < want - tol || got > want + tol) begin
      $display("FAILED: %s = %0.15g, want %0.15g", what, got, want);
      failures += 1;
    end
  endtask

  cg_fixed f;
  cg_set s;
  cg_huge h;
  cg_union ua, ub, uc;
  initial begin
    f = new;
    s = new(2);
    h = new;
    ua = new(0, 99999);
    ub = new(200000, 299999);
    uc = new(0, 9);

    v = 150;  w = 0; f.sample();
    v = 1000; w = 0; f.sample();
    // lo claims bins 50..100 of cp (102 tuples): 1 + 39999898 bins.
    check("fixed", f.x.get_inst_coverage(), 100.0 * 2 / (1.0 + 40000000 - 102));

    v = 5; w = 0; s.sample();     // the set bin s
    v = 9; w = 1; s.sample();     // an automatic bin
    // s claims 2 tuples: 1 + 199998 bins.
    check("set", s.x.get_inst_coverage(), 100.0 * 2 / (1.0 + 200000 - 2));

    a = 3; b = 4; h.sample();
    check("huge", h.x.get_inst_coverage(), 100.0 / (2.0 ** 80));

    u = 3;      w = 0; ua.sample(); uc.sample();
    u = 250000; w = 1; ub.sample();
    // ua: 200000 - 2*10001; ub: 200000; uc (dense) lies inside ua.
    // Two names hit: (3,0) and (250000,1).
    check("union", ua.x.get_coverage(),
          100.0 * 2 / (200000.0 - 20002 + 200000));
    if (failures == 0) $display("PASSED");
  end
endmodule
