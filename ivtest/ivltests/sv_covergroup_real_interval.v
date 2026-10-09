module sv_covergroup_real_interval;
  real value, boundary, multiple, ignored, illegal_value;
  shortreal short_value;
  bit value_en, boundary_en, multiple_en, ignored_en, illegal_en, short_en;

  covergroup cg;
    type_option.real_interval = 0.01;
    value_cp: coverpoint value iff (value_en) {
      bins b[] = {[0.75:0.85]};
    }
    boundary_cp: coverpoint boundary iff (boundary_en) {
      bins b[] = {[0.75:0.85]};
    }
    multiple_cp: coverpoint multiple iff (multiple_en) {
      bins b[] = {[0.00:0.02], [1.00:1.02]};
    }
    short_cp: coverpoint short_value iff (short_en) {
      type_option.real_interval = 0.1;
      bins b[] = {[1.0:1.3]};
    }
    ignored_cp: coverpoint ignored iff (ignored_en) {
      bins b[] = {[0.00:0.03]};
      ignore_bins skip = {[0.01:0.02]};
    }
    illegal_cp: coverpoint illegal_value iff (illegal_en) {
      bins b[] = {[0.00:0.03]};
      illegal_bins bad = {0.02};
    }
  endgroup

  cg cov = new;

  initial begin
    value = 0.755; value_en = 1; cov.sample();
    value_en = 0; value = 0.845; value_en = 1; cov.sample();
    value_en = 0;
    if (cov.value_cp.get_inst_coverage() != 20.0)
      $fatal(1, "real interval range did not create ten bins");

    boundary = 0.76; boundary_en = 1; cov.sample(); boundary_en = 0;
    if (cov.boundary_cp.get_inst_coverage() != 10.0)
      $fatal(1, "a shared boundary matched more than one real bin");
    boundary = 0.85; boundary_en = 1; cov.sample(); boundary_en = 0;
    if (cov.boundary_cp.get_inst_coverage() != 20.0)
      $fatal(1, "the final real interval endpoint was not included");

    multiple = 0.015; multiple_en = 1; cov.sample();
    multiple_en = 0; multiple = 1.015; multiple_en = 1; cov.sample();
    multiple_en = 0;
    if (cov.multiple_cp.get_inst_coverage() != 50.0)
      $fatal(1, "multiple real ranges did not create four bins");

    short_value = 1.05; short_en = 1; cov.sample();
    short_en = 0; short_value = 1.25; short_en = 1; cov.sample();
    short_en = 0;
    if (cov.short_cp.get_inst_coverage() < 66.6
        || cov.short_cp.get_inst_coverage() > 66.7)
      $fatal(1, "shortreal interval bins were not sampled");

    ignored = 0.015; ignored_en = 1; cov.sample(); ignored_en = 0;
    if (cov.ignored_cp.get_inst_coverage() != 0.0)
      $fatal(1, "ignore_bins did not carve a real interval");
    ignored = 0.025; ignored_en = 1; cov.sample(); ignored_en = 0;
    if (cov.ignored_cp.get_inst_coverage() != 50.0)
      $fatal(1, "ignore_bins changed the surviving real-bin denominator");
    ignored = 0.03; ignored_en = 1; cov.sample(); ignored_en = 0;
    if (cov.ignored_cp.get_inst_coverage() != 50.0)
      $fatal(1, "the final real endpoint escaped its interval bin");

    illegal_value = 0.02; illegal_en = 1; cov.sample(); illegal_en = 0;
    if (cov.illegal_cp.get_inst_coverage() != 0.0)
      $fatal(1, "illegal_bins did not suppress the real coverpoint sample");
    illegal_value = 0.025; illegal_en = 1; cov.sample(); illegal_en = 0;
    if (cov.illegal_cp.get_inst_coverage() < 33.3
        || cov.illegal_cp.get_inst_coverage() > 33.4)
      $fatal(1, "illegal_bins changed the real-bin denominator");

    $display("PASSED");
  end
endmodule
