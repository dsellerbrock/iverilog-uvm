// Issue #3303 (IEEE 1800-2023 19.6, 19.6.1, 19.11): a cross with more than
// 65536 bins is counted sparsely instead of being disabled. Each automatic
// bin is one tuple of the crossed coverpoints' bins; ignore, illegal and
// named cross bins are excluded from the automatic bins.
module top;
  int v; bit w;
  int failures = 0;

  covergroup cg_inst(int hi);
    option.per_instance = 1;
    cp: coverpoint v { bins big[] = {[0:hi]}; }
    cq: coverpoint w;
    x:  cross cp, cq;
    xi: cross cp, cq { ignore_bins ig = binsof(cq) intersect {1}; }
    xn: cross cp, cq { bins lo = binsof(cp) intersect {[0:9]}; }
    xl: cross cp, cq { illegal_bins il = binsof(cp) intersect {7}
                                         && binsof(cq) intersect {0}; }
    xa: cross cp, cq { option.at_least = 2; }
  endgroup

  // Constant bin array over 65536 values (#3285), crossed.
  covergroup cg_const;
    cp: coverpoint v { bins big[] = {[0:99999]}; }
    cq: coverpoint w;
    x:  cross cp, cq;
  endgroup

  // Type coverage (19.11.3): merge_instances merges the instances' bins
  // by name; otherwise it is the average of the instance coverages.
  covergroup cg_type(int hi);
    type_option.merge_instances = 1;
    cp: coverpoint v { bins big[] = {[0:hi]}; }
    cq: coverpoint w;
    x:  cross cp, cq;
  endgroup
  covergroup cg_avg(int hi);
    cp: coverpoint v { bins big[] = {[0:hi]}; }
    cq: coverpoint w;
    x:  cross cp, cq;
  endgroup

  task automatic check(string what, real got, real want);
    if (got < want - 1.0e-9 || got > want + 1.0e-9) begin
      $display("FAILED: %s = %0.10f, want %0.10f", what, got, want);
      failures += 1;
    end
  endtask

  cg_inst e;
  cg_const c;
  cg_type t1, t2;
  cg_avg a1, a2;
  initial begin
    e = new(99999);
    c = new;
    t1 = new(99999);
    t2 = new(99999);
    a1 = new(99999);
    a2 = new(99999);
    v = 3;  w = 0; e.sample(); c.sample(); t1.sample(); a1.sample();
    v = 20; w = 0; e.sample(); e.sample();
    v = 20; w = 1; e.sample();
    v = 7;  w = 0; e.sample();
    v = 3;  w = 0; t2.sample(); a2.sample();
    v = 4;  w = 1; t2.sample(); a2.sample();

    // 200000 tuples; hits (3,0) (20,0) (20,1) (7,0).
    check("x",  e.x.get_inst_coverage(),  100.0 * 4 / 200000);
    // ignore removes w==1: 100000 bins, hits (3,0) (20,0) (7,0).
    check("xi", e.xi.get_inst_coverage(), 100.0 * 3 / 100000);
    // lo claims 20 tuples: 1 + 199980 bins; lo, (20,0), (20,1) hit.
    check("xn", e.xn.get_inst_coverage(), 100.0 * 3 / 199981);
    // the illegal tuple (7,0) is not a bin: 199999 bins.
    check("xl", e.xl.get_inst_coverage(), 100.0 * 3 / 199999);
    // at_least 2: only (20,0) was sampled twice.
    check("xa", e.xa.get_inst_coverage(), 100.0 * 1 / 200000);
    check("const", c.x.get_inst_coverage(), 100.0 * 1 / 200000);
    // (3,0) hit in both instances is one bin; (4,1) is the other.
    check("merged", t1.x.get_coverage(), 100.0 * 2 / 200000);
    // a1 hit 1 bin and a2 2 bins.
    check("average", a1.x.get_coverage(), 100.0 * 1.5 / 200000);
    if (failures == 0) $display("PASSED");
  end
endmodule
