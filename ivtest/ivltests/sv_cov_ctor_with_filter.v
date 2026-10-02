// IEEE 1800-2017/2023 19.5.1, 19.5.7: a bin whose range depends on a
// constructor argument and carries a `with' filter. The filter partitions the
// domain, the constructor bound clips it per instance. OpenTitan i2c's
// i2c_fifo_level_cg `others' bin has exactly this shape.
module test;
  covergroup cg(int unsigned depth) with function sample(int lvl);
    option.per_instance = 1;
    cp: coverpoint lvl {
      bins lvl_b[] = {1, 4, 8, 16};
      bins others = {[0:depth]} with (!(item inside {1, 4, 8, 16}));
    }
  endgroup
  cg c, d16, d17;
  real cov;
  initial begin
    c = new(10); d16 = new(16); d17 = new(17);
    c.sample(11); c.sample(-3);
    cov = c.get_inst_coverage();
    if (cov != 0.0) $fatal(1, "out-of-range sample counted: %f", cov);
    c.sample(4);
    cov = c.get_inst_coverage();
    if (cov != 20.0) $fatal(1, "filtered value 4 reached others: %f", cov);
    c.sample(8);
    c.sample(2);
    cov = c.get_inst_coverage();
    if (cov != 60.0) $fatal(1, "2 did not hit others: %f", cov);
    c.sample(1); c.sample(16);
    cov = c.get_inst_coverage();
    if (cov != 100.0) $fatal(1, "full coverage expected: %f", cov);
    d16.sample(17);
    cov = d16.get_inst_coverage();
    if (cov != 0.0) $fatal(1, "17 is above depth 16: %f", cov);
    d17.sample(17);
    cov = d17.get_inst_coverage();
    if (cov != 20.0) $fatal(1, "17 is within depth 17: %f", cov);
    $display("PASSED");
  end
endmodule
