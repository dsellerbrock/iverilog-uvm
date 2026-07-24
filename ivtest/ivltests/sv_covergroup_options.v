// Covergroup option/type_option semantics + automatic bin sizing
// (IEEE 1800-2017 19.5.1, 19.7.1). Previously automatic bins for any
// non-parent-property source (standalone covergroups, sample()
// formals, expressions) were spread over a 2**32 space, so narrow
// sources silently piled every sample into bin 0; enum coverpoints
// got a uniform split instead of one bin per named value; and
// procedural option reads collapsed to 0 with no diagnostic (now a
// loud sorry). option.detect_overlap now reports overlapping bins at
// compile time.
module main;
  bit failed = 0;
  task check(string label, bit ok);
    if (!ok) begin
       $display("FAILED -- %0s", label);
       failed = 1;
    end
  endtask

  // at_least: a bin needs option.at_least hits to count as covered
  bit [1:0] v1;
  covergroup cg_al;
    option.at_least = 2;
    option.goal = 90;              // accepted metadata (no effect)
    option.comment = "al";
    type_option.weight = 3;
    cp: coverpoint v1 { bins b[] = {0,1,2,3}; }
  endgroup

  // per-coverpoint weight scales the instance coverage average
  bit [1:0] wa; bit wb;
  covergroup cg_w;
    cp_a: coverpoint wa { option.weight = 3; bins x[] = {0,1,2,3}; }
    cp_b: coverpoint wb { option.weight = 1; bins y[] = {0,1}; }
  endgroup

  // auto_bin_max over a 5-bit signal: 4 uniform bins of 8 values
  bit [4:0] v2;
  covergroup cg_abm;
    cp: coverpoint v2 { option.auto_bin_max = 4; }
  endgroup

  // automatic bins sized from the source: 3-bit signal -> 8 bins;
  // enum -> one bin per named value; 2-bit expression -> 4 bins;
  // 2-bit sample() formal -> 4 bins
  typedef enum { E0, E1, E2 } e_t;
  e_t es;
  bit [2:0] v3;
  bit [1:0] xa, xb;
  covergroup cg_auto;
    cp_n: coverpoint v3;
    cp_e: coverpoint es;
    cp_x: coverpoint (xa ^ xb);
  endgroup
  covergroup cg_wf with function sample(bit [1:0] m);
    cp_m: coverpoint m;
  endgroup

  cg_al   al = new;
  cg_w    w  = new;
  cg_abm  ab = new;
  cg_auto au = new;
  cg_wf   wf = new;

  initial begin
    v1 = 0; al.sample();
    v1 = 1; al.sample(); al.sample();
    // bin0 once (below at_least=2), bin1 twice -> 1 of 4
    check("option.at_least", al.get_inst_coverage() == 25.0);

    wa = 0; wb = 0; w.sample();
    wa = 1; wb = 1; w.sample();
    // cp_a 50% w3 + cp_b 100% w1 -> 62.5
    check("option.weight", w.get_inst_coverage() == 62.5);

    v2 = 0; ab.sample();
    v2 = 9; ab.sample();
    // bins [0:7],[8:15],[16:23],[24:31]: 2 of 4
    check("option.auto_bin_max", ab.get_inst_coverage() == 50.0);

    v3 = 0; es = E0; xa = 0; xb = 1; au.sample();
    v3 = 7; es = E2; xa = 3; xb = 1; au.sample();
    // cp_n 2/8=25, cp_e 2/3, cp_x 2/4=50 -> (25 + 66.67 + 50)/3 = 47.2
    check("auto-bin widths", au.get_inst_coverage() > 47.2 &&
                             au.get_inst_coverage() < 47.3);

    wf.sample(0);
    wf.sample(3);
    // 2 of 4 formal-typed auto bins
    check("formal auto bins", wf.get_inst_coverage() == 50.0);

    if (!failed) $display("PASSED");
    $finish(0);
  end
endmodule
