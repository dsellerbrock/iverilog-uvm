module issue1438_cross_type_name_scope;
  covergroup cg with function sample(bit a, bit b);
    type_option.merge_instances = 1;
    option.get_inst_coverage = 1;
    ca: coverpoint a;
    cb: coverpoint b;
    cx: cross ca, cb;
  endgroup

  cg cov;
  initial begin
    cg::cx::type_option.weight = 0;
    cov = new;
    cov.sample(0, 0);
    cov.sample(1, 1);
    if (cov.get_coverage() < 99.99 || cov.get_coverage() > 100.01)
      $fatal(1, "type-scoped cross weight did not affect type coverage");
    if (cov.get_inst_coverage() < 83.32 || cov.get_inst_coverage() > 83.34)
      $fatal(1, "type-scoped cross weight changed instance coverage");
    $display("PASSED");
    $finish(0);
  end
endmodule
