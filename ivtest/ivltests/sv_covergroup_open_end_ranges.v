// IEEE 1800-2017/2023: $ in a covergroup range is the type-domain bound.
module test;
  covergroup unsigned_cg with function sample(bit [7:0] value, bit enable);
    option.per_instance = 1;
    cp: coverpoint value {
      bins low = {[$:3]};
      bins high = {[250:$]};
    }
    en: coverpoint enable { bins off = {0}; bins on = {1}; }
    cx: cross cp, en;
  endgroup

  covergroup signed_cg with function sample(bit signed [7:0] value);
    option.per_instance = 1;
    cp: coverpoint value {
      bins low = {[$:-2]};
      bins high = {[2:$]};
    }
  endgroup

  // This must remain one logical bin; expanding the interval is impractical.
  covergroup wide_cg with function sample(bit [31:0] value);
    option.per_instance = 1;
    cp: coverpoint value { bins nonzero = {[1:$]}; }
  endgroup

  covergroup overflow_cg with function sample(bit [7:0] value);
    option.per_instance = 1;
    cp: coverpoint value {
      bins unreachable = {[300:$]};
      bins reachable = {7};
    }
  endgroup

  covergroup signed_overflow_cg with function sample(bit signed [7:0] value);
    option.per_instance = 1;
    cp: coverpoint value {
      bins unreachable = {[$:-200]};
      bins reachable = {7};
    }
  endgroup

  // An empty open-ended intersection must not select a dynamic cross bin.
  covergroup dynamic_cross_cg(int limit)
      with function sample(bit [7:0] value, bit enable);
    option.per_instance = 1;
    cp: coverpoint value { bins bounded = {[0:limit]}; }
    en: coverpoint enable { bins off = {0}; }
    cx: cross cp, en {
      illegal_bins impossible = binsof(cp) intersect {[300:$]};
    }
  endgroup

  covergroup carve_cg with function sample(bit [3:0] value);
    option.per_instance = 1;
    cp: coverpoint value {
      bins active[] = {[$:15]};
      ignore_bins high = {[14:$]};
      illegal_bins zero = {[$:0]};
    }
  endgroup

  covergroup signed_span_cg with function sample(bit signed [7:0] value);
    option.per_instance = 1;
    cp: coverpoint value {
      bins through_zero = {[$:3]};
      bins above = {[4:$]};
    }
  endgroup

  covergroup named_cross_cg with function sample(bit [3:0] value, bit enable);
    option.per_instance = 1;
    cp: coverpoint value {
      bins low = {[$:3]};
      bins high = {[12:$]};
    }
    en: coverpoint enable { bins off = {0}; bins on = {1}; }
    cx: cross cp, en {
      bins high_on = binsof(cp) intersect {[12:$]} && binsof(en.on);
    }
  endgroup

  unsigned_cg uc = new;
  signed_cg sc = new;
  wide_cg wc = new;
  overflow_cg oc = new;
  signed_overflow_cg soc = new;
  dynamic_cross_cg dc = new(1);
  carve_cg cc = new;
  signed_span_cg ssc = new;
  named_cross_cg nc = new;

  function automatic bit near(real got, real want);
    return got > want - 0.01 && got < want + 0.01;
  endfunction

  initial begin
    uc.sample(4, 0);
    if (!near(uc.get_inst_coverage(), 16.6667))
      $fatal(1, "unsigned gap or cross denominator: %f", uc.get_inst_coverage());
    uc.sample(0, 0);
    if (!near(uc.get_inst_coverage(), 41.6667))
      $fatal(1, "low endpoint or cross hit: %f", uc.get_inst_coverage());
    uc.sample(255, 1);
    if (!near(uc.get_inst_coverage(), 83.3333))
      $fatal(1, "high endpoint or cross hit: %f", uc.get_inst_coverage());
    uc.sample(0, 1);
    uc.sample(255, 0);
    if (!near(uc.get_inst_coverage(), 100.0))
      $fatal(1, "cross did not retain all four bins");

    sc.sample(0);
    if (sc.get_inst_coverage() != 0.0)
      $fatal(1, "signed gap matched an open range");
    sc.sample(-128);
    if (sc.get_inst_coverage() != 50.0)
      $fatal(1, "signed lower domain bound was omitted");
    sc.sample(127);
    if (sc.get_inst_coverage() != 100.0)
      $fatal(1, "signed upper domain bound was omitted");

    wc.sample(0);
    if (wc.get_inst_coverage() != 0.0)
      $fatal(1, "wide bin accepted zero");
    wc.sample(32'hffff_ffff);
    if (wc.get_inst_coverage() != 100.0)
      $fatal(1, "wide open interval was dropped");

    oc.sample(255);
    if (oc.get_inst_coverage() != 0.0)
      $fatal(1, "out-of-domain lower bound became a false singleton");
    oc.sample(7);
    if (oc.get_inst_coverage() != 100.0)
      $fatal(1, "out-of-domain lower bound inflated bin count");

    soc.sample(-128);
    if (soc.get_inst_coverage() != 0.0)
      $fatal(1, "out-of-domain upper bound became a false singleton");
    soc.sample(7);
    if (soc.get_inst_coverage() != 100.0)
      $fatal(1, "out-of-domain upper bound inflated bin count");

    dc.sample(0, 0);
    if (dc.get_inst_coverage() != 100.0)
      $fatal(1, "empty cross intersection selected a dynamic bin");

    cc.sample(1);
    if (!near(cc.get_inst_coverage(), 100.0/13.0))
      $fatal(1, "open-ended ignore/illegal carving changed bin count");
    cc.sample(14);
    if (!near(cc.get_inst_coverage(), 100.0/13.0))
      $fatal(1, "ignored upper interval counted as covered");

    ssc.sample(-128);
    if (ssc.get_inst_coverage() != 50.0)
      $fatal(1, "signed open interval lost its negative half");
    ssc.sample(0);
    if (ssc.get_inst_coverage() != 50.0)
      $fatal(1, "signed open interval split into extra bins");
    ssc.sample(127);
    if (ssc.get_inst_coverage() != 100.0)
      $fatal(1, "signed open interval lost its upper bound");

    nc.sample(12, 1);
    if (!near(nc.get_inst_coverage(), 41.6667))
      $fatal(1, "named open intersection selected wrong cross bins");

    $display("PASSED");
  end
endmodule
