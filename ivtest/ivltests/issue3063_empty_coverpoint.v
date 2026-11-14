module issue3063_empty_coverpoint;
  bit v;
  covergroup cg;
    empty_zero: coverpoint v { option.weight = 0; bins omit = {0}; ignore_bins ign = {0}; }
    empty_one: coverpoint v { bins omit = {0}; ignore_bins ign = {0}; }
    partial: coverpoint v { bins vals = {[0:1]}; ignore_bins ign = {0}; }
    auto_cp: coverpoint v { ignore_bins ign = {0}; }
  endgroup
  covergroup cg_inst;
    option.get_inst_coverage = 1;
    cp: coverpoint v { option.weight = 0; bins omit = {0}; ignore_bins ign = {0}; }
  endgroup
  cg c = new;
  cg_inst ci = new;
  initial begin
    v = 0; c.sample();
    if (c.empty_zero.get_inst_coverage() != 100.0 ||
        c.empty_zero.get_coverage() != 100.0 ||
        c.empty_one.get_inst_coverage() != 0.0 ||
        c.partial.get_inst_coverage() != 0.0 ||
        c.auto_cp.get_inst_coverage() != 0.0)
      $fatal(1, "initial coverage incorrect: %f %f %f %f %f",
             c.empty_zero.get_inst_coverage(), c.empty_zero.get_coverage(),
             c.empty_one.get_inst_coverage(), c.partial.get_inst_coverage(),
             c.auto_cp.get_inst_coverage());
    if (ci.cp.get_inst_coverage() != 100.0)
      $fatal(1, "instance empty coverage incorrect");
    ci.cp.option.weight = 1;
    if (ci.cp.get_inst_coverage() != 0.0)
      $fatal(1, "changed weight coverage incorrect");
    v = 1; c.sample();
    if (c.empty_one.get_inst_coverage() != 0.0 ||
        c.partial.get_inst_coverage() != 100.0 ||
        c.auto_cp.get_inst_coverage() != 100.0)
      $fatal(1, "sampled coverage incorrect");
    $display("PASS");
  end
endmodule
