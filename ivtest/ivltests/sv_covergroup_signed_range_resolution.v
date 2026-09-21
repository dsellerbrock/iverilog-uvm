module test;
  covergroup signed3_cg with function sample(bit signed [2:0] value);
    option.per_instance = 1;
    cp: coverpoint value { bins clipped[] = {[-6:6]}; }
  endgroup
  covergroup unsigned3_cg with function sample(bit [2:0] value);
    option.per_instance = 1;
    cp: coverpoint value {
      bins excluded = {-1};
      bins clipped[] = {[6:10]};
      bins rest = default;
    }
  endgroup
  covergroup carved_cg with function sample(int value);
    option.per_instance = 1;
    cp: coverpoint value {
      bins values[] = {[-2:2]};
      ignore_bins ignored = {-1};
      illegal_bins illegal = {1};
    }
  endgroup
  covergroup xz_cg with function sample(logic [3:0] value);
    option.per_instance = 1;
    cp: coverpoint value {
      bins bad = {'x};
      bins good = {0};
    }
  endgroup
  signed3_cg sc;
  unsigned3_cg uc;
  carved_cg cc;
  xz_cg xc;
  initial begin
    sc = new;
    for (int i = -4; i <= 3; i++) begin
      sc.sample(i);
      if (sc.get_inst_coverage() < 12.5*(i+5)-0.001 ||
          sc.get_inst_coverage() > 12.5*(i+5)+0.001)
        $fatal(1, "signed narrow clipping step %0d: %f", i,
               sc.get_inst_coverage());
    end

    uc = new;
    uc.sample(6);
    if (uc.get_inst_coverage() != 50.0)
      $fatal(1, "unsigned clipped first value %f", uc.get_inst_coverage());
    uc.sample(7);
    if (uc.get_inst_coverage() != 100.0)
      $fatal(1, "unsigned clipped second value %f", uc.get_inst_coverage());
    uc.sample(0);
    if (uc.get_inst_coverage() != 100.0)
      $fatal(1, "unsigned default affected denominator %f", uc.get_inst_coverage());

    cc = new;
    cc.sample(-2);
    if (cc.get_inst_coverage() < 33.332 || cc.get_inst_coverage() > 33.334)
      $fatal(1, "signed carving first value %f", cc.get_inst_coverage());
    cc.sample(0);
    if (cc.get_inst_coverage() < 66.665 || cc.get_inst_coverage() > 66.667)
      $fatal(1, "signed carving second value %f", cc.get_inst_coverage());
    cc.sample(2);
    if (cc.get_inst_coverage() != 100.0)
      $fatal(1, "signed carving denominator %f", cc.get_inst_coverage());
    xc = new;
    xc.sample(0);
    if (xc.get_inst_coverage() != 100.0)
      $fatal(1, "X/Z empty bin affected denominator %f", xc.get_inst_coverage());
    $display("PASSED");
  end
endmodule
