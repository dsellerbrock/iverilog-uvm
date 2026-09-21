module sv_covergroup_cross_recursive_with;
  int a, b;

  function automatic bit near(real got, real want);
    return got > want - 0.01 && got < want + 0.01;
  endfunction

  covergroup union_cg;
    ca: coverpoint a { bins lo = {0}; bins hi = {1}; }
    cb: coverpoint b { bins lo = {0}; bins hi = {1}; }
    cx: cross ca, cb {
      // Three products belong to picked; <1,0> remains one automatic bin.
      bins picked = (binsof(ca) with (ca == 0)) ||
                    (binsof(cb) with (cb == 1));
    }
  endgroup

  covergroup boolean_cg;
    ca: coverpoint a { bins lo = {0}; bins hi = {1}; }
    cb: coverpoint b { bins lo = {0}; bins hi = {1}; }
    cx: cross ca, cb {
      // Parentheses retain the predicate on each leaf: only <0,1> is both.
      bins both = ((binsof(ca) with (ca == 0)) &&
                   (binsof(cb) with (cb == 1)));
      // This counter would be hit by <1,*> unless the complement ignores it.
      bins hi = binsof(ca) with (ca == 1);
      // Complement is applied after its child's with selection: <1,*>.
      ignore_bins not_lo = !(binsof(ca) with (ca == 0));
    }
  endgroup

  covergroup repeated_cg;
    ca: coverpoint a { bins lo = {0}; bins hi = {1}; }
    cb: coverpoint b { bins lo = {0}; bins hi = {1}; }
    cx: cross ca, cb {
      // Two suffixes must remain nested: only <0,1> belongs to repeated.
      bins repeated = binsof(ca) with (ca == 0) with (cb == 1);
      bins other = binsof(ca) with (ca == 1) with (cb == 1);
    }
  endgroup

  covergroup range_cg;
    ca: coverpoint a { bins pair = {[0:1]}; }
    cb: coverpoint b { bins one = {1}; }
    cx: cross ca, cb {
      // Default matches 1: the pair bin is selected because value tuple <1,1>
      // satisfies the predicate, including when the runtime sample is <0,1>.
      bins any_value = binsof(ca) with (ca == cb);
    }
  endgroup

  union_cg u = new;
  boolean_cg q = new;
  repeated_cg p = new;
  range_cg r = new;

  initial begin
    a = 0; b = 0; u.sample();
    if (!near(u.get_inst_coverage(), 50.0)) $fatal(1, "union lost its automatic product");
    a = 1; b = 0; u.sample();
    if (!near(u.get_inst_coverage(), 83.3333)) $fatal(1, "union selected the wrong products");
    a = 1; b = 1; u.sample();
    if (!near(u.get_inst_coverage(), 100.0)) $fatal(1, "union changed aggregate coverage");

    a = 1; b = 0; q.sample();
    if (!near(q.get_inst_coverage(), 33.3333)) $fatal(1, "complement did not ignore <1,0>");
    a = 0; b = 1; q.sample();
    if (!near(q.get_inst_coverage(), 83.3333)) $fatal(1, "intersection selected the wrong tuples");
    a = 0; b = 0; q.sample();
    if (!near(q.get_inst_coverage(), 100.0)) $fatal(1, "parenthesized intersection changed the denominator");

    a = 0; b = 1; p.sample();
    if (!near(p.get_inst_coverage(), 41.6667)) $fatal(1, "repeated with suffix overwrote a predicate");

    a = 0; b = 1; r.sample();
    if (!near(r.get_inst_coverage(), 100.0)) $fatal(1, "range-valued with lost default matches 1");
    $display("PASSED");
  end
endmodule
