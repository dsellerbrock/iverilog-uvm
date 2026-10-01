module top;
  covergroup average_cg with function sample(bit x);
    type_option.merge_instances = 0;
    option.get_inst_coverage = 1;
    cp: coverpoint x;
  endgroup
  covergroup merged_cg with function sample(bit x);
    type_option.merge_instances = 1;
    option.get_inst_coverage = 1;
    cp: coverpoint x;
  endgroup
  covergroup merged0_cg with function sample(bit x);
    type_option.merge_instances = 1;
    option.get_inst_coverage = 0;
    cp: coverpoint x;
  endgroup
  covergroup empty_cg with function sample(bit x);
    type_option.merge_instances = 0;
    option.get_inst_coverage = 1;
    cp: coverpoint x {
      option.weight = 0;
      bins b[] = {[0:1]};
      ignore_bins all = {[0:1]};
    }
  endgroup
  average_cg a, b;
  merged_cg ma, mb;
  merged0_cg na, nb;
  empty_cg z;
  initial begin
    a = new;
    b = new;
    a.option.weight = 3;
    b.option.weight = 1;
    a.cp.option.weight = 1;
    b.cp.option.weight = 3;
    a.sample(0);
    b.sample(0);
    b.sample(1);
    if (a.cp.get_coverage() != 87.5 ||
        b.cp.get_coverage() != 87.5 ||
        a.cp.get_inst_coverage() != 50.0 ||
        b.cp.get_inst_coverage() != 100.0)
      $fatal(1, "weighted type=%f inst=%f/%f", a.cp.get_coverage(), a.cp.get_inst_coverage(), b.cp.get_inst_coverage());
    b = null;
    if (a.cp.get_coverage() != 87.5)
      $fatal(1, "retired type=%f", a.cp.get_coverage());

    ma = new;
    mb = new;
    ma.sample(0);
    mb.sample(1);
    if (ma.cp.get_coverage() != 100.0 ||
        mb.cp.get_coverage() != 100.0 ||
        ma.cp.get_inst_coverage() != 50.0)
      $fatal(1, "merged type=%f inst=%f", ma.cp.get_coverage(), ma.cp.get_inst_coverage());
    na = new;
    nb = new;
    na.sample(0);
    nb.sample(1);
    if (na.cp.get_inst_coverage() != 100.0)
      $fatal(1, "merged inst option=%f", na.cp.get_inst_coverage());

    z = new;
    if (z.cp.get_coverage() != 100.0 ||
        z.cp.get_inst_coverage() != 100.0)
      $fatal(1, "empty type=%f inst=%f", z.cp.get_coverage(), z.cp.get_inst_coverage());
    $display("PASSED");
  end
endmodule
