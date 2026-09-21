module test;
  covergroup open_cg with function sample(int value);
    option.per_instance = 1;
    cp: coverpoint value {
      bins close[] = {[-4:4], [-1:1]};
      bins far = default;
    }
  endgroup
  covergroup fixed_cg with function sample(int value);
    option.per_instance = 1;
    cp: coverpoint value { bins halves[2] = {[-4:4]}; }
  endgroup
  covergroup filter_cg with function sample(int value);
    option.per_instance = 1;
    cp: coverpoint value {
      bins neg = {[-4:4]} with (item inside {[-4:-1]});
      bins nonneg = {[0:4]};
    }
  endgroup
  open_cg oc;
  fixed_cg fc;
  filter_cg wc;
  real got, want;
  initial begin
    oc = new;
    for (int i = -4; i <= 4; i++) begin
      oc.sample(i);
      got = oc.get_inst_coverage();
      want = 100.0 * (i + 5) / 9.0;
      if (got < want-0.0001 || got > want+0.0001)
        $fatal(1, "open signed bin %0d got %f want %f", i, got, want);
      oc.sample(i);
      if (oc.get_inst_coverage() != got)
        $fatal(1, "overlap/duplicate changed denominator at %0d", i);
    end
    oc.sample(100);
    if (oc.get_inst_coverage() != 100.0)
      $fatal(1, "default bin changed completed coverage");

    fc = new;
    fc.sample(-4);
    if (fc.get_inst_coverage() != 50.0)
      $fatal(1, "fixed signed first partition %f", fc.get_inst_coverage());
    fc.sample(-1);
    if (fc.get_inst_coverage() != 50.0)
      $fatal(1, "fixed signed boundary reordered %f", fc.get_inst_coverage());
    fc.sample(0);
    if (fc.get_inst_coverage() != 100.0)
      $fatal(1, "fixed signed second partition %f", fc.get_inst_coverage());

    wc = new;
    wc.sample(-4);
    if (wc.get_inst_coverage() != 50.0)
      $fatal(1, "signed inside filter negative %f", wc.get_inst_coverage());
    wc.sample(0);
    if (wc.get_inst_coverage() != 100.0)
      $fatal(1, "signed inside filter default %f", wc.get_inst_coverage());
    $display("PASSED");
  end
endmodule
