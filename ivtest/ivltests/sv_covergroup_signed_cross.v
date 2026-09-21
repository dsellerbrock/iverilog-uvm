module test;
  function automatic bit near(real got, real want);
    return got > want - 0.001 && got < want + 0.001;
  endfunction
  covergroup cg with function sample(int a, bit b);
    option.per_instance = 1;
    ca: coverpoint a {
      option.weight = 0;
      bins neg = {[-4:-1]};
      bins pos = {[0:4]};
    }
    cb: coverpoint b { option.weight = 0; }
    x: cross ca, cb {
      bins neg_zero = binsof(ca) intersect {[-4:-1]} &&
                      binsof(cb) intersect {0};
    }
  endgroup
  cg c;
  initial begin
    c = new;
    c.sample(-4, 0);
    if (!near(c.get_inst_coverage(), 25.0))
      $fatal(1, "signed named cross first tuple %f", c.get_inst_coverage());
    c.sample(-4, 1);
    if (!near(c.get_inst_coverage(), 50.0))
      $fatal(1, "signed retained cross second tuple %f", c.get_inst_coverage());
    c.sample(4, 0);
    if (!near(c.get_inst_coverage(), 75.0))
      $fatal(1, "signed retained cross third tuple %f", c.get_inst_coverage());
    c.sample(4, 1);
    if (!near(c.get_inst_coverage(), 100.0))
      $fatal(1, "signed retained cross denominator %f", c.get_inst_coverage());
    $display("PASSED");
  end
endmodule
