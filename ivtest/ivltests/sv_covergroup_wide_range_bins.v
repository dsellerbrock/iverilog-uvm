// IEEE 1800-2017/2023 §19.5.1: explicit covergroup value ranges define
// the set of values associated with the bin, including for wide coverpoints.
module sv_covergroup_wide_range_bins;
  typedef logic [255:0] wide_t;
  typedef logic [64:0] edge_t;
  bit guarded_ignore_active;

  covergroup full_range_cg with function sample(input wide_t value);
    cp: coverpoint value {
      bins full = {[256'h0:
        256'hffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff]};
    }
  endgroup

  covergroup bounded_range_cg with function sample(input wide_t value);
    cp: coverpoint value {
      bins span = {[256'h000000000000000000000000000000000000000000000001ffffffffffffffff:
                    256'h0000000000000000000000000000000000000000000000020000000000000001]};
      bins other = {[256'h300:256'h3ff]};
    }
  endgroup

  covergroup bounded_cross_cg with function sample(input wide_t value,
                                                    input bit selector);
    cp: coverpoint value {
      bins span = {[256'h000000000000000000000000000000000000000000000001ffffffffffffffff:
                    256'h0000000000000000000000000000000000000000000000020000000000000001]};
    }
    sel: coverpoint selector { bins one = {1}; }
    x: cross cp, sel;
  endgroup

  covergroup narrow_range_cg with function sample(input bit [63:0] value);
    cp: coverpoint value {
      bins span = {[64'h1:64'h3]};
    }
  endgroup

  covergroup edge_range_cg with function sample(input edge_t value);
    cp: coverpoint value {
      bins span = {[65'h0ffffffffffffffff:65'h10000000000000001]};
    }
  endgroup

  covergroup ignored_range_cg with function sample(input wide_t value);
    cp: coverpoint value {
      bins ignored_span = {[256'h0:256'hff]};
      bins kept = {256'h100};
      ignore_bins skip = {[256'h0:256'hff]};
    }
  endgroup

  covergroup illegal_range_cg with function sample(input wide_t value);
    cp: coverpoint value {
      bins illegal_span = {[256'h0:256'hff]};
      bins kept = {256'h100};
      illegal_bins bad = {[256'h0:256'hff]};
    }
  endgroup

  covergroup adjacent_ignored_range_cg with function sample(input wide_t value);
    cp: coverpoint value {
      bins removed = {[256'h0:256'hc8]};
      bins kept = {256'h300};
      ignore_bins skip_low = {[256'h0:256'h64]};
      ignore_bins skip_high = {[256'h65:256'hc8]};
    }
  endgroup

  covergroup multi_range_cg with function sample(input wide_t value);
    cp: coverpoint value {
      bins alternatives = {[256'h10:256'h20], [256'hc8:256'hdc]};
      bins other = {256'h300};
    }
  endgroup

  covergroup partial_ignored_range_cg with function sample(input wide_t value);
    cp: coverpoint value {
      bins span = {[256'h0:256'hc8]};
      bins other = {256'h300};
      ignore_bins middle = {[256'h32:256'h64]};
    }
  endgroup

  covergroup guarded_ignored_range_cg with function sample(input wide_t value);
    cp: coverpoint value {
      bins span = {[256'h0:256'hc8]};
      bins other = {256'h300};
      ignore_bins gated = {[256'h0:256'hc8]} iff (guarded_ignore_active);
    }
  endgroup

  full_range_cg full = new;
  bounded_range_cg bounded = new;
  bounded_cross_cg bounded_cross = new;
  narrow_range_cg narrow = new;
  edge_range_cg edge_cg = new;
  ignored_range_cg ignored = new;
  illegal_range_cg illegal = new;
  adjacent_ignored_range_cg adjacent_ignored = new;
  multi_range_cg multi_range = new;
  partial_ignored_range_cg partial_ignored = new;
  guarded_ignored_range_cg guarded_ignored = new;
  wide_t unknown_value;

  initial begin
    full.sample({256{1'b1}});
    if (full.cp.get_inst_coverage() != 100)
      $fatal(1, "full 256-bit value range did not match");

    bounded.sample(256'h000000000000000000000000000000000000000000000001fffffffffffffffe);
    bounded.sample(256'h0000000000000000000000000000000000000000000000020000000000000002);
    unknown_value = 256'h000000000000000000000000000000000000000000000001ffffffffffffffff;
    unknown_value[0] = 1'bx;
    bounded.sample(unknown_value);
    unknown_value = 256'h000000000000000000000000000000000000000000000001ffffffffffffffff;
    unknown_value[1] = 1'bz;
    bounded.sample(unknown_value);
    if (bounded.cp.get_inst_coverage() != 0)
      $fatal(1, "out-of-range or X/Z value matched a bounded wide bin");

    bounded.sample(256'h000000000000000000000000000000000000000000000001ffffffffffffffff);
    bounded.sample(256'h0000000000000000000000000000000000000000000000020000000000000000);
    bounded.sample(256'h0000000000000000000000000000000000000000000000020000000000000001);
    if (bounded.cp.get_inst_coverage() != 50)
      $fatal(1, "one of two bounded 256-bit bins did not report 50% coverage");
    bounded.sample(256'h355);
    if (bounded.cp.get_inst_coverage() != 100)
      $fatal(1, "second bounded 256-bit bin did not bring coverage to 100%");

    bounded_cross.sample(256'h000000000000000000000000000000000000000000000001fffffffffffffffe, 1);
    if (bounded_cross.x.get_inst_coverage() != 0)
      $fatal(1, "out-of-range value matched a wide range cross");
    bounded_cross.sample(256'h000000000000000000000000000000000000000000000001ffffffffffffffff, 1);
    if (bounded_cross.x.get_inst_coverage() != 100)
      $fatal(1, "in-range value did not match a wide range cross");

    narrow.sample(64'h2);
    if (narrow.cp.get_inst_coverage() != 100)
      $fatal(1, "64-bit value range control did not match");

    edge_cg.sample(65'h0fffffffffffffffe);
    edge_cg.sample(65'h10000000000000002);
    if (edge_cg.cp.get_inst_coverage() != 0)
      $fatal(1, "out-of-range value matched a 65-bit boundary range");
    edge_cg.sample(65'h0ffffffffffffffff);
    edge_cg.sample(65'h10000000000000000);
    edge_cg.sample(65'h10000000000000001);
    if (edge_cg.cp.get_inst_coverage() != 100)
      $fatal(1, "65-bit boundary range did not match");

    ignored.sample(256'h100);
    if (ignored.cp.get_inst_coverage() != 100)
      $fatal(1, "fully ignored wide range remained in the coverage denominator");

    illegal.sample(256'h100);
    if (illegal.cp.get_inst_coverage() != 100)
      $fatal(1, "fully illegal wide range remained in the coverage denominator");

    guarded_ignore_active = 1;
    guarded_ignored.sample(256'h64);
    if (guarded_ignored.cp.get_inst_coverage() != 0)
      $fatal(1, "active iff ignore did not suppress its range");
    guarded_ignore_active = 0;
    guarded_ignored.sample(256'h64);
    if (guarded_ignored.cp.get_inst_coverage() != 50)
      $fatal(1, "inactive iff ignore removed a normal bin from the denominator");
    guarded_ignored.sample(256'h300);
    if (guarded_ignored.cp.get_inst_coverage() != 100)
      $fatal(1, "guarded-ignore control bin did not complete coverage");

    multi_range.sample(256'hd2);
    if (multi_range.cp.get_inst_coverage() != 50)
      $fatal(1, "second disjoint range alternative did not match its bin");
    multi_range.sample(256'h300);
    if (multi_range.cp.get_inst_coverage() != 100)
      $fatal(1, "multi-range alternative bin did not complete coverage");

    partial_ignored.sample(256'h4b);
    if (partial_ignored.cp.get_inst_coverage() != 0)
      $fatal(1, "partial ignored overlap counted as a normal-bin hit");
    partial_ignored.sample(256'h19);
    if (partial_ignored.cp.get_inst_coverage() != 50)
      $fatal(1, "partial ignore removed a still-valid normal bin");
    partial_ignored.sample(256'h300);
    if (partial_ignored.cp.get_inst_coverage() != 100)
      $fatal(1, "partial-ignore control bin did not complete coverage");

    adjacent_ignored.sample(256'h300);
    if (adjacent_ignored.cp.get_inst_coverage() != 100)
      $fatal(1, "adjacent ignore ranges left a fully carved bin in the denominator");

  end
endmodule
