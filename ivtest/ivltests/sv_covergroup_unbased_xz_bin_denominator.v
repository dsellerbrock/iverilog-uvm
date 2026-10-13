module test;
  covergroup cg with function sample(logic [3:0] value);
    cp: coverpoint value {
      bins unknown = {'x};
      bins known_zero = {0};
    }
  endgroup

  cg cov;
  initial begin
    cov = new;
    cov.sample(4'b0000);
    if (cov.get_inst_coverage() != 50.0)
      $fatal(1, "unhit X bin denominator %f", cov.get_inst_coverage());
    cov.sample(4'bxxxx);
    if (cov.get_inst_coverage() != 50.0)
      $fatal(1, "nonmatching X sample changed coverage %f",
             cov.get_inst_coverage());
    cov.sample(4'b000x);
    if (cov.get_inst_coverage() != 100.0)
      $fatal(1, "exact X bin did not match %f", cov.get_inst_coverage());
    $display("PASSED");
  end
endmodule
