module sv_covergroup_cross_with_range_values;
  int a, b;

  covergroup equal_filter;
    option.per_instance = 1;
    ca: coverpoint a { bins low = {[0:3]}; bins high = {4}; }
    cb: coverpoint b { bins low = {[0:3]}; bins high = {4}; }
    cx: cross ca, cb {
      ignore_bins equal_low = (binsof(ca.low) && binsof(cb.low))
                              with (ca == cb);
    }
  endgroup

  covergroup false_filter;
    option.per_instance = 1;
    ca: coverpoint a { bins low = {[0:3]}; bins high = {4}; }
    cb: coverpoint b { bins low = {[0:3]}; bins high = {4}; }
    cx: cross ca, cb {
      ignore_bins impossible = (binsof(ca.low) && binsof(cb.low))
                               with (ca > 10);
    }
  endgroup

  covergroup multirange_filter;
    option.per_instance = 1;
    ca: coverpoint a { bins split = {0, [2:3]}; bins neighbor = {1}; }
    cb: coverpoint b { bins split = {0, [2:3]}; bins neighbor = {1}; }
    cx: cross ca, cb {
      ignore_bins equal_split = (binsof(ca.split) && binsof(cb.split))
                                with (ca == cb);
    }
  endgroup

  covergroup signed_filter;
    option.per_instance = 1;
    ca: coverpoint a { bins span = {[-2:1]}; bins neighbor = {2}; }
    cb: coverpoint b { bins span = {[-2:1]}; bins neighbor = {2}; }
    cx: cross ca, cb {
      ignore_bins equal_span = (binsof(ca.span) && binsof(cb.span))
                               with (ca == cb);
    }
  endgroup

  covergroup overlap_filter;
    option.per_instance = 1;
    ca: coverpoint a { bins overlap = {[-2:0], [-1:1], 0}; bins neighbor = {2}; }
    cb: coverpoint b { bins overlap = {[-2:0], [-1:1], 0}; bins neighbor = {2}; }
    cx: cross ca, cb {
      ignore_bins selected = (binsof(ca.overlap) && binsof(cb.overlap))
                             with (ca == 1 && cb == -2);
    }
  endgroup

  equal_filter eq = new;
  false_filter no = new;
  multirange_filter mr = new;
  signed_filter sg = new;
  overlap_filter ov = new;

  function automatic bit near(real got, real want);
    return got > want - 0.01 && got < want + 0.01;
  endfunction

  initial begin
    // Default matches=1 removes the whole low/low bin tuple because at
    // least one value tuple (for example 0/0) satisfies the predicate.
    a = 0; b = 4; eq.sample();
    a = 4; b = 0; eq.sample();
    a = 4; b = 4; eq.sample();
    if (!near(eq.get_inst_coverage(), 100.0))
      $fatal(1, "range-valued true predicate did not remove its bin tuple");

    // A predicate false for every value tuple retains low/low in the
    // denominator. Cover the three neighbors first, then the retained tuple.
    a = 0; b = 4; no.sample();
    a = 4; b = 0; no.sample();
    a = 4; b = 4; no.sample();
    if (!near(no.get_inst_coverage(), 91.6667))
      $fatal(1, "false predicate removed a range-valued bin tuple");
    a = 0; b = 0; no.sample();
    if (!near(no.get_inst_coverage(), 100.0))
      $fatal(1, "retained range-valued bin tuple did not collect coverage");

    // Multiple disjoint ranges in one bin participate in the same value
    // tuple search; singleton neighboring bins remain ordinary cross bins.
    a = 0; b = 1; mr.sample();
    a = 1; b = 0; mr.sample();
    a = 1; b = 1; mr.sample();
    if (!near(mr.get_inst_coverage(), 100.0))
      $fatal(1, "multi-range predicate or singleton neighbor was misrouted");

    // A signed interval crossing zero is a four-value set, not the enormous
    // unsigned interval between encodings of +1 and -2.
    a = -2; b = 2; sg.sample();
    a = 2; b = -2; sg.sample();
    a = 2; b = 2; sg.sample();
    if (!near(sg.get_inst_coverage(), 100.0))
      $fatal(1, "signed range crossing zero was not enumerated correctly");

    // Bin values form a set: duplicates and overlap do not multiply the
    // value-tuple count or change predicate truth.
    a = -2; b = 2; ov.sample();
    a = 2; b = -2; ov.sample();
    a = 2; b = 2; ov.sample();
    if (!near(ov.get_inst_coverage(), 100.0))
      $fatal(1, "overlapping range values changed with-predicate selection");

    $display("PASSED");
    $finish;
  end
endmodule
