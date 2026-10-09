module sv_covergroup_cross_matches;
  localparam int MATCH_THRESHOLD = 4;
  int a, b;

  covergroup cg;
    option.per_instance = 1;
    ca: coverpoint a {
      option.weight = 0;
      bins a0 = {0, 1};
      bins a1 = {2, 3};
      bins a2 = {4, 5};
    }
    cb: coverpoint b {
      option.weight = 0;
      bins b01 = {0, 1};
    }
    x_exact: cross ca, cb {
      option.at_least = 2;
      bins selected = (binsof(ca.a0) || binsof(ca.a1))
                      with ((cb == 0) || (cb == 1)) matches MATCH_THRESHOLD;
    }
    x_above: cross ca, cb {
      option.at_least = 2;
      bins selected = (binsof(ca.a0) || binsof(ca.a1))
                      with ((cb == 0) || (cb == 1)) matches 5;
    }
    x_default: cross ca, cb {
      option.at_least = 2;
      bins selected = (binsof(ca.a0) || binsof(ca.a1)) with (cb == 0);
    }
    x_all: cross ca, cb {
      option.at_least = 2;
      bins selected = (binsof(ca.a0) || binsof(ca.a1))
                      with ((cb == 0) || (cb == 1)) matches $;
    }
    x_not_all: cross ca, cb {
      option.at_least = 2;
      bins selected = (binsof(ca.a0) || binsof(ca.a1))
                      with (cb == 0) matches $;
    }
  endgroup

  cg cov = new;

  initial begin
    a = 0; b = 0; cov.sample();
    a = 2; b = 0; cov.sample();
    if (cov.x_exact.get_inst_coverage() != 50.0)
      $fatal(1, "matches at satisfying-tuple count did not group candidates");
    if (cov.x_above.get_inst_coverage() != 0.0)
      $fatal(1, "above-count matches selected a candidate bin tuple");
    if (cov.x_default.get_inst_coverage() != 50.0)
      $fatal(1, "omitted matches did not default to one");
    if (cov.x_all.get_inst_coverage() != 50.0)
      $fatal(1, "matches $ rejected a candidate whose tuples all satisfy");
    if (cov.x_not_all.get_inst_coverage() != 0.0)
      $fatal(1, "matches $ selected a candidate with an unsatisfied tuple");
    $display("PASSED");
  end
endmodule
