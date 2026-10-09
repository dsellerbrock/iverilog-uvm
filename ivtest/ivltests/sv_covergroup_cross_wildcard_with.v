module sv_covergroup_cross_wildcard_with;
  bit [1:0] a;
  bit b;

  covergroup cg;
    option.per_instance = 1;
    ca: coverpoint a {
      option.weight = 0;
      wildcard bins low = {2'b0?};
      wildcard bins high = {2'b1?};
    }
    cb: coverpoint b {
      option.weight = 0;
      bins both = {0, 1};
    }
    cx: cross ca, cb {
      option.at_least = 2;
      bins low_a = binsof(ca) with (ca == 0);
    }
  endgroup

  cg cov = new;

  initial begin
    a = 0; b = 0; cov.sample();
    a = 1; b = 1; cov.sample();
    if (cov.cx.get_inst_coverage() != 50.0)
      $fatal(1, "wildcard low values did not select exactly one cross bin");
    a = 2; b = 0; cov.sample();
    if (cov.cx.get_inst_coverage() != 50.0)
      $fatal(1, "wildcard high bin matched a predicate for value zero");
    a = 3; b = 1; cov.sample();
    if (cov.cx.get_inst_coverage() != 100.0)
      $fatal(1, "unselected wildcard cross bin was missing from denominator");
    $display("PASSED");
  end
endmodule
