module sv_covergroup_wildcard_array;
  logic [3:0] value;

  covergroup cg;
    cp: coverpoint value {
      wildcard bins entries[] = {4'b11??};
    }
  endgroup

  cg cov = new;

  initial begin
    value = 4'bxxxx;
    cov.sample();
    if (cov.get_inst_coverage() != 0.0)
      $fatal(1, "wildcard array matched an X sample");

    value = 12;
    cov.sample();
    if (cov.get_inst_coverage() != 25.0)
      $fatal(1, "wildcard array did not create four value bins");
    value = 13;
    cov.sample();
    if (cov.get_inst_coverage() != 50.0)
      $fatal(1, "wildcard array did not count the second value bin");
    value = 12;
    cov.sample();
    if (cov.get_inst_coverage() != 50.0)
      $fatal(1, "wildcard array counted one value in multiple bins");
    value = 14;
    cov.sample();
    if (cov.get_inst_coverage() != 75.0)
      $fatal(1, "wildcard array did not count the third value bin");
    value = 15;
    cov.sample();
    if (cov.get_inst_coverage() != 100.0)
      $fatal(1, "wildcard array did not count the fourth value bin");

    $display("wildcard_array_coverage=%0.1f", cov.get_inst_coverage());
    $display("PASSED");
    $finish;
  end
endmodule
