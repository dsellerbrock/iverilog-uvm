// IEEE 1800-2023 19.6.1, 19.7 Tables 19-1/19-2, and 19.10: when
// cross_retain_auto_bins is zero, an explicit bin removes uncovered autos.
// The same source is also compiled with -g2017 to pin the edition boundary.
module top;
  function automatic bit near(real got, real want);
    return got > want - 0.01 && got < want + 0.01;
  endfunction

  covergroup cg(int n) with function sample(int idx, bit flag);
    option.per_instance = 1;
    cp_idx: coverpoint idx {
      bins each[] = {[0:n-1]};
    }
    cp_flag: coverpoint flag;
    idx_x_flag: cross cp_idx, cp_flag {
      option.cross_retain_auto_bins = 0;
      bins selected = binsof(cp_idx) intersect {0} &&
                      binsof(cp_flag) intersect {0};
    }
  endgroup

  // The edition rule is not specific to constructor-dependent dimensions.
  // Pin the fixed elaboration path with the same topology and oracle.
  covergroup fixed_cg with function sample(int idx, bit flag);
    option.per_instance = 1;
    cp_idx: coverpoint idx {
      bins zero = {0};
      bins one = {1};
    }
    cp_flag: coverpoint flag;
    idx_x_flag: cross cp_idx, cp_flag {
      option.cross_retain_auto_bins = 0;
      bins selected = binsof(cp_idx.zero) && binsof(cp_flag) intersect {0};
    }
  endgroup

  // With no explicit normal/ignore/illegal bin declaration, automatic bins
  // remain even when the option is zero.
  covergroup automatic_only_cg(int n)
      with function sample(int idx, bit flag);
    option.per_instance = 1;
    cp_idx: coverpoint idx {
      bins each[] = {[0:n-1]};
    }
    cp_flag: coverpoint flag;
    idx_x_flag: cross cp_idx, cp_flag {
      option.cross_retain_auto_bins = 0;
    }
  endgroup

  // A covergroup-level setting is the default for every enclosed cross.  Pin
  // both dynamic and fixed elaboration paths; neither cross repeats the option.
  covergroup inherited_dynamic_cg(int n)
      with function sample(int idx, bit flag);
    option.per_instance = 1;
    option.cross_retain_auto_bins = 0;
    cp_idx: coverpoint idx {
      bins each[] = {[0:n-1]};
    }
    cp_flag: coverpoint flag;
    idx_x_flag: cross cp_idx, cp_flag {
      bins selected = binsof(cp_idx) intersect {0} &&
                      binsof(cp_flag) intersect {0};
    }
  endgroup

  covergroup inherited_fixed_cg with function sample(int idx, bit flag);
    option.per_instance = 1;
    option.cross_retain_auto_bins = 0;
    cp_idx: coverpoint idx {
      bins zero = {0};
      bins one = {1};
    }
    cp_flag: coverpoint flag;
    idx_x_flag: cross cp_idx, cp_flag {
      bins selected = binsof(cp_idx.zero) && binsof(cp_flag) intersect {0};
    }
  endgroup

  // Cross-local state overrides the enclosing covergroup default in either
  // direction. This is the opposite precedence direction from cg above.
  covergroup override_enable_cg(int n)
      with function sample(int idx, bit flag);
    option.per_instance = 1;
    option.cross_retain_auto_bins = 0;
    cp_idx: coverpoint idx {
      bins each[] = {[0:n-1]};
    }
    cp_flag: coverpoint flag;
    idx_x_flag: cross cp_idx, cp_flag {
      option.cross_retain_auto_bins = 1;
      bins selected = binsof(cp_idx) intersect {0} &&
                      binsof(cp_flag) intersect {0};
    }
  endgroup

  // Any explicit bins declaration has presence semantics, including ignore
  // and illegal bins whose selectors resolve to an empty set. With retention
  // disabled, neither cross may recover unclaimed automatic bins.
  covergroup empty_special_cg(int n)
      with function sample(int idx, bit flag);
    option.per_instance = 1;
    cp_idx: coverpoint idx {
      bins each[] = {[0:n-1]};
    }
    cp_flag: coverpoint flag;
    ignore_x: cross cp_idx, cp_flag {
      option.cross_retain_auto_bins = 0;
      ignore_bins empty = binsof(cp_idx) intersect {99};
    }
    illegal_x: cross cp_idx, cp_flag {
      option.cross_retain_auto_bins = 0;
      illegal_bins empty = binsof(cp_idx) intersect {99};
    }
  endgroup

  cg cov = new(2);
  fixed_cg fixed_cov = new;
  automatic_only_cg automatic_only_cov = new(2);
  inherited_dynamic_cg inherited_dynamic_cov = new(2);
  inherited_fixed_cg inherited_fixed_cov = new;
  override_enable_cg override_enable_cov = new(2);
  empty_special_cg empty_special_cov = new(2);

  initial begin
    // This tuple is not selected by the explicit bin. The two coverpoints
    // are each half covered and the cross is uncovered: (50+50+0)/3.
    cov.sample(1, 1);
    if (!near(cov.get_inst_coverage(), 33.3333))
      $fatal(1, "unclaimed automatic cross bins were retained");

    // The selected tuple covers the cross's sole denominator bin.
    cov.sample(0, 0);
    if (!near(cov.get_inst_coverage(), 100.0))
      $fatal(1, "explicit cross bin was not the complete denominator");

    fixed_cov.sample(1, 1);
    if (!near(fixed_cov.get_inst_coverage(), 33.3333))
      $fatal(1, "fixed cross retained an unclaimed automatic bin");
    fixed_cov.sample(0, 0);
    if (!near(fixed_cov.get_inst_coverage(), 100.0))
      $fatal(1, "fixed explicit cross bin was not the complete denominator");

    automatic_only_cov.sample(1, 1);
    if (!near(automatic_only_cov.get_inst_coverage(), 41.6667))
      $fatal(1, "option removed automatic bins without an explicit bin");

    inherited_dynamic_cov.sample(1, 1);
    if (!near(inherited_dynamic_cov.get_inst_coverage(), 33.3333))
      $fatal(1, "dynamic cross ignored the covergroup retention default");

    inherited_fixed_cov.sample(1, 1);
    if (!near(inherited_fixed_cov.get_inst_coverage(), 33.3333))
      $fatal(1, "fixed cross ignored the covergroup retention default");

    override_enable_cov.sample(1, 1);
    if (!near(override_enable_cov.get_inst_coverage(), 41.6667))
      $fatal(1, "cross-local retention did not override the group default");

    empty_special_cov.sample(1, 1);
    if (!near(empty_special_cov.get_inst_coverage(), 50.0))
      $fatal(1, "empty ignore/illegal declarations did not suppress autos");

    $display("PASSED");
    $finish;
  end
endmodule
