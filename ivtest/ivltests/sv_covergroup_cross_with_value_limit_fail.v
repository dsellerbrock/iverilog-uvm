module sv_covergroup_cross_with_value_limit_fail;
  int a, b;
  covergroup cg;
    ca: coverpoint a { bins all = {[0:65536]}; }
    cb: coverpoint b { bins all = {0}; }
    cx: cross ca, cb {
      // 65,537 value tuples exceed the bounded evaluator. This must be a
      // compile error; selecting nothing would fabricate coverage topology.
      bins too_large = (binsof(ca) && binsof(cb)) with (ca == cb);
    }
  endgroup
  cg cov = new;
endmodule
