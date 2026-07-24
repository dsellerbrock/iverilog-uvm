// Adversarial covergroup semantics (IEEE 1800-2017 19.5.5, 19.5.6,
// 19.6.1, 19.9): ignore_bins/illegal_bins values are carved out of
// the coverpoint's other bins and the cross product (previously a
// fully-ignored bin stayed in the denominator and could never be
// hit); multi-step transition bins run a per-instance NFA; binsof
// cross selects route tuples; get_coverage() is the type-level merge
// across instances and $get_coverage the design mean (previously
// duplicate class compiles left zero-count registry orphans that
// dragged the mean toward 0).
module main;
  bit failed = 0;
  task check(string label, bit ok);
    if (!ok) begin
       $display("FAILED -- %0s", label);
       failed = 1;
    end
  endtask

  // ignore carve: x[] = {0,1,2,3} with ignore {3} -> 3 countable bins;
  // cross product excludes the carved value (3x2=6 tuples)
  bit [1:0] a; bit b;
  covergroup cg_ig;
    cp_a: coverpoint a { bins x[] = {0,1,2,3}; ignore_bins ig = {3}; }
    cp_b: coverpoint b { bins y[] = {0,1}; }
    axb: cross cp_a, cp_b;
  endgroup

  // transitions: 2-step and 3-step sequences, per-instance NFA state
  bit [1:0] t;
  covergroup cg_tr;
    cp: coverpoint t {
      bins s01 = (0 => 1);
      bins s123 = (1 => 2 => 3);
      bins b[] = {0,1,2,3};
    }
  endgroup

  // binsof cross selects: ignore carves 2 tuples, illegal routes 1
  bit [1:0] xa; bit xb;
  covergroup cg_bo;
    cp_a: coverpoint xa { bins x[] = {0,1,2,3}; }
    cp_b: coverpoint xb { bins y[] = {0,1}; }
    axb: cross cp_a, cp_b {
      ignore_bins skip = binsof(cp_a) intersect {3};
      illegal_bins bad = binsof(cp_a) intersect {2} && binsof(cp_b) intersect {1};
    }
  endgroup

  // type-level merge across instances
  bit [1:0] m;
  covergroup cg_ty;
    cp: coverpoint m { bins b[] = {0,1,2,3}; }
  endgroup

  cg_ig ig1 = new;
  cg_tr tr1 = new;
  cg_tr tr2 = new;
  cg_bo bo1 = new;
  cg_ty ty1 = new;
  cg_ty ty2 = new;

  initial begin
    a = 0; b = 0; ig1.sample();
    a = 3; b = 1; ig1.sample();   // ignored value: nothing counts
    a = 1; b = 1; ig1.sample();
    // cp_a 2/3, cp_b 2/2, cross {(0,0),(1,1)} of 6 -> (66.67+100+33.33)/3
    check("ignore carve", ig1.get_inst_coverage() > 66.6 &&
                          ig1.get_inst_coverage() < 66.7);

    t = 0; tr1.sample();
    t = 1; tr1.sample();          // tr1: s01
    t = 2; tr1.sample();
    t = 3; tr1.sample();          // tr1: s123
    t = 0; tr2.sample();
    t = 3; tr2.sample();          // tr2: no transitions complete
    check("transitions", tr1.get_inst_coverage() == 100.0);
    check("per-instance NFA", tr2.get_inst_coverage() > 33.3 &&
                              tr2.get_inst_coverage() < 33.4);

    xa = 0; xb = 0; bo1.sample();
    // cp_a 1/4, cp_b 1/2, cross 1/5 (8 tuples - 2 ignored - 1 illegal)
    check("binsof cross", bo1.get_inst_coverage() > 31.6 &&
                          bo1.get_inst_coverage() < 31.7);

    m = 0; ty1.sample();
    m = 1; ty2.sample();
    // inst: 1/4 each; type merge: 2/4
    check("inst vs type", ty1.get_inst_coverage() == 25.0 &&
                          ty1.get_coverage() == 50.0);

    // $get_coverage is the mean of the type coverages; duplicate
    // class compiles used to leave zero-count registry orphans that
    // dragged this below the true mean.
    begin
      real expect_mean, got;
      expect_mean = (ig1.get_coverage() + tr1.get_coverage()
                     + bo1.get_coverage() + ty1.get_coverage()) / 4.0;
      got = $get_coverage();
      check("$get_coverage mean", got > expect_mean - 0.01 &&
                                  got < expect_mean + 0.01);
    end

    if (!failed) $display("PASSED");
    $finish(0);
  end
endmodule
