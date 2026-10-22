module test;
  logic [3:0] v;
  covergroup cg;
    cp: coverpoint v {
      bins valid[] = {1, 2};
      ignore_bins ignored = {0, 3};
    }
  endgroup
  cg cov = new();
  initial begin
    v = 0; cov.sample();
    v = 3; cov.sample();
    if (cov.get_inst_coverage() != 0.0)
      $fatal(1, "ignored values contributed to coverage: %0f", cov.get_inst_coverage());
    v = 1; cov.sample();
    v = 2; cov.sample();
    if (cov.get_inst_coverage() != 100.0)
      $fatal(1, "ignore-bin coverage=%0f, expected 100", cov.get_inst_coverage());
    $display("P19_05_05_IGNORE_BINS_PASS");
    $finish;
  end
endmodule
