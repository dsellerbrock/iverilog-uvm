// IEEE 1800-2017/2023 19.9 with 19.3 and 19.5.1: a constructor-dependent
// (runtime-valued) coverpoint bin family must contribute to TYPE coverage --
// get_coverage() and $get_coverage() -- not only to per-instance coverage.
//
// A static bin owns a counter property that the type view reads directly. A
// runtime family instead resolves a per-instance bin set, so its merged hits
// live in a (family, bin) map and its size is whatever the instances
// resolved. The type-level accounting skipped such families entirely, so a
// covergroup whose only bins were runtime-valued reported 0.00 type coverage
// while reading 100.00 per instance -- coverage silently lost exactly where
// UVM and dvsim read it. sv_covergroup_ctor_bin_ranges pins the per-instance
// behavior and calls get_inst_coverage() only, which is why this hid.
//
// TEST DESIGN: type coverage is cumulative across every instance of a
// covergroup TYPE for the whole simulation, so each check below uses its own
// covergroup type. Sharing one type between checks lets an earlier
// instance's hits satisfy a later assertion and the test silently passes.
module top;

  // Runtime-valued bins, fully covered.
  covergroup cg_full(int hi) with function sample(int v);
    option.per_instance = 1;
    cp: coverpoint v { bins b[] = {[1:hi]}; }
  endgroup

  // Runtime-valued bins, half covered: pins the DENOMINATOR. If the family
  // contributed hits but no size, this would read 100.00.
  covergroup cg_half(int hi) with function sample(int v);
    option.per_instance = 1;
    cp: coverpoint v { bins b[] = {[1:hi]}; }
  endgroup

  // A static bin and a runtime bin on one coverpoint.
  covergroup cg_mixed(int hi) with function sample(int v);
    option.per_instance = 1;
    cp: coverpoint v { bins stat = {100}; bins dyn = {[1:hi]}; }
  endgroup

  // The OpenTitan TL agent shape: an expression over the formal.
  covergroup cg_tl(int valid_source_width) with function sample(int source);
    option.per_instance = 1;
    cp: coverpoint source { bins valid_sources[] = {[0 : 2 << (valid_source_width - 1) - 1]}; }
  endgroup

  // Two instances of one type resolving DIFFERENT bin sets. The merged view
  // takes the widest resolved set (8) against the union of hit bins (2).
  covergroup cg_merge(int hi) with function sample(int v);
    option.per_instance = 1;
    cp: coverpoint v { bins b[] = {[1:hi]}; }
  endgroup

  // option.per_instance = 0 must not change type accounting.
  covergroup cg_noinst(int hi) with function sample(int v);
    option.per_instance = 0;
    cp: coverpoint v { bins b[] = {[1:hi]}; }
  endgroup

  // Constant-range control: unchanged by this fix.
  covergroup cg_const with function sample(int v);
    option.per_instance = 1;
    cp: coverpoint v { bins b[] = {[1:4]}; }
  endgroup

  int fails = 0;

  task automatic ck(string tag, real got, real want);
    // Coverage percentages here are exact small fractions.
    if (got != want) begin
      fails += 1;
      $display("FAILED: %s type coverage got %0.2f want %0.2f", tag, got, want);
    end
  endtask

  cg_full   f;
  cg_half   h;
  cg_mixed  m;
  cg_tl     t;
  cg_merge  g_narrow, g_wide;
  cg_noinst n;
  cg_const  c;

  initial begin
    // 4 runtime bins, all hit.
    f = new(4);
    for (int i = 1; i <= 4; i++) f.sample(i);
    ck("cg_full",  f.get_coverage(), 100.0);
    ck("cg_full inst", f.get_inst_coverage(), 100.0);

    // 4 runtime bins, 2 hit.
    h = new(4);
    h.sample(1); h.sample(2);
    ck("cg_half",  h.get_coverage(), 50.0);
    ck("cg_half inst", h.get_inst_coverage(), 50.0);

    // static bin hit, runtime bin unhit -> 1 of 2.
    m = new(4);
    m.sample(100);
    ck("cg_mixed static only", m.get_coverage(), 50.0);
    m.sample(2);
    ck("cg_mixed both", m.get_coverage(), 100.0);

    // width 2 -> [0:2], three bins.
    t = new(2);
    t.sample(0); t.sample(1); t.sample(2);
    ck("cg_tl", t.get_coverage(), 100.0);

    // Widest set is 8; union of hit bins is {1,2}.
    g_narrow = new(2); g_narrow.sample(1); g_narrow.sample(2);
    g_wide   = new(8); g_wide.sample(1);   g_wide.sample(2);
    ck("cg_merge", g_narrow.get_coverage(), 25.0);
    ck("cg_merge narrow inst", g_narrow.get_inst_coverage(), 100.0);
    ck("cg_merge wide inst",   g_wide.get_inst_coverage(), 25.0);

    n = new(4);
    for (int i = 1; i <= 4; i++) n.sample(i);
    ck("cg_noinst", n.get_coverage(), 100.0);

    c = new();
    for (int i = 1; i <= 4; i++) c.sample(i);
    ck("cg_const", c.get_coverage(), 100.0);
    ck("cg_const inst", c.get_inst_coverage(), 100.0);

    if (fails == 0) $display("PASSED");
  end

endmodule
