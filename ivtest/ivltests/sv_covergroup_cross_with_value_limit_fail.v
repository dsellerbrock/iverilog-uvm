module sv_covergroup_cross_with_value_limit_fail;
  int a, b;
  covergroup cg;
    ca: coverpoint a { bins all = {[0:65536]}; }
    cb: coverpoint b { bins all = {0}; }
    cx: cross ca, cb {
      // 65,537 value tuples with a non-relational predicate still exceed
      // the bounded evaluator. Selecting nothing would fabricate coverage.
      bins too_large = (binsof(ca) && binsof(cb)) with (ca + 1 == cb);
    }
  endgroup
  cg cov = new;
endmodule
