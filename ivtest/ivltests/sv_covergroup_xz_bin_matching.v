class xz_bin_holder;
  logic [1:0] value;

  covergroup known_bins;
    cp: coverpoint value {
      bins zero = {2'b00};
      bins one = {2'b01};
    }
  endgroup

  covergroup explicit_unknown_bins;
    cp: coverpoint value {
      bins x_zero = {2'bx0};
      bins z_one = {2'bz1};
      bins zero = {2'b00};
    }
  endgroup

  covergroup wildcard_bin;
    cp: coverpoint value {
      wildcard bins low_one = {2'b?1};
    }
  endgroup

  bit choose;
  covergroup cross_unknown_bins;
    cp_value: coverpoint value {
      bins x_zero = {2'bx0};
      bins z_one = {2'bz1};
    }
    cp_choose: coverpoint choose {
      bins low = {1'b0};
      bins high = {1'b1};
    }
    x: cross cp_value, cp_choose;
  endgroup

  function new;
    known_bins = new;
    explicit_unknown_bins = new;
    wildcard_bin = new;
    cross_unknown_bins = new;
  endfunction
endclass

module main;
  xz_bin_holder h;
  real coverage;
  logic expression_flag;
  covergroup expression_known_bins;
    cp: coverpoint (expression_flag ^ 1'b0) {
      bins zero = {1'b0};
      bins one = {1'b1};
    }
  endgroup
  expression_known_bins expression_bins;

  initial begin
    h = new;
    expression_bins = new;

    h.value = 2'bx0;
    h.known_bins.sample();
    if (h.known_bins.get_inst_coverage() != 0.0)
      $fatal(1, "X sample matched a known-value bin");
    h.value = 2'bz1;
    h.known_bins.sample();
    if (h.known_bins.get_inst_coverage() != 0.0)
      $fatal(1, "Z sample matched a known-value bin");

    h.value = 2'bx0;
    h.explicit_unknown_bins.sample();
    coverage = h.explicit_unknown_bins.get_inst_coverage();
    if (coverage < 33.0 || coverage > 34.0)
      $fatal(1, "X bin coverage was %0f, expected one of three bins", coverage);
    h.value = 2'bz0;
    h.explicit_unknown_bins.sample();
    if (h.explicit_unknown_bins.get_inst_coverage() != coverage)
      $fatal(1, "Z sample matched an X bin with different bits");
    h.value = 2'bx1;
    h.explicit_unknown_bins.sample();
    if (h.explicit_unknown_bins.get_inst_coverage() != coverage)
      $fatal(1, "X sample matched an X bin with different bits");
    h.value = 2'bz1;
    h.explicit_unknown_bins.sample();
    coverage = h.explicit_unknown_bins.get_inst_coverage();
    if (coverage < 66.0 || coverage > 67.0)
      $fatal(1, "Z bin coverage was %0f, expected two of three bins", coverage);
    h.value = 2'b00;
    h.explicit_unknown_bins.sample();
    coverage = h.explicit_unknown_bins.get_inst_coverage();
    if (coverage != 100.0)
      $fatal(1, "known bin did not match after X/Z bins: %0f", coverage);

    expression_flag = 1'bx;
    expression_bins.sample();
    if (expression_bins.get_inst_coverage() != 0.0)
      $fatal(1, "expression X sample matched a known-value bin");
    expression_flag = 1'bz;
    expression_bins.sample();
    if (expression_bins.get_inst_coverage() != 0.0)
      $fatal(1, "expression Z sample matched a known-value bin");
    expression_flag = 1'b0;
    expression_bins.sample();
    if (expression_bins.get_inst_coverage() < 49.0
        || expression_bins.get_inst_coverage() > 51.0)
      $fatal(1, "expression known sample did not match its bin");

    h.value = 2'bx1;
    h.wildcard_bin.sample();
    if (h.wildcard_bin.get_inst_coverage() != 0.0)
      $fatal(1, "wildcard bin matched an X sample");
    h.value = 2'bz1;
    h.wildcard_bin.sample();
    if (h.wildcard_bin.get_inst_coverage() != 0.0)
      $fatal(1, "wildcard bin matched a Z sample");
    h.value = 2'b01;
    h.wildcard_bin.sample();
    if (h.wildcard_bin.get_inst_coverage() != 100.0)
      $fatal(1, "wildcard bin did not match a known sample");

    h.value = 2'bx0;
    h.choose = 1'b0;
    h.cross_unknown_bins.sample();
    if (h.cross_unknown_bins.x.get_inst_coverage() < 24.0
        || h.cross_unknown_bins.x.get_inst_coverage() > 26.0)
      $fatal(1, "X/Z cross did not match an exact X bin");
    h.value = 2'bz1;
    h.choose = 1'b1;
    h.cross_unknown_bins.sample();
    if (h.cross_unknown_bins.x.get_inst_coverage() < 49.0
        || h.cross_unknown_bins.x.get_inst_coverage() > 51.0)
      $fatal(1, "X/Z cross did not match an exact Z bin");

    $display("PASSED");
  end
endmodule
