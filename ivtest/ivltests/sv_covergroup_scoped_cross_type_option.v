// IEEE 1800-2017/2023 19.6 and 19.7.1: a cross name is visible after
// covergroup type scope resolution, and its type weight is mutable.
module sv_covergroup_scoped_cross_type_option;
  bit a, b;
  covergroup cg;
    type_option.merge_instances = 1;
    ca: coverpoint a { type_option.weight = 0; }
    cb: coverpoint b { type_option.weight = 0; }
    cx: cross ca, cb;
  endgroup

  cg cov;
  initial begin
    cov = new;
    a = 0;
    b = 0;
    cov.sample();
    if (cov.get_coverage() != 25.0)
      $fatal(1, "cross type weight should contribute to merged coverage");
    cg::cx::type_option.weight = 0;
    if (cov.get_coverage() != 0.0)
      $fatal(1, "type-scoped cross weight was not updated");
    $display("PASSED");
    $finish(0);
  end
endmodule
