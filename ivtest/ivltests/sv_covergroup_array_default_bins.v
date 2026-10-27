module test;
  covergroup cg with function sample(bit [1:0] value);
    option.per_instance = 1;
    cp: coverpoint value {
      bins zero = {0};
      bins others[] = default;
    }
  endgroup

  cg coverage;
  initial begin
    coverage = new;
    coverage.sample(0);
    if (coverage.get_inst_coverage() != 100.0)
      $fatal(1, "default array bins entered coverage denominator");
    coverage.sample(1);
    coverage.sample(2);
    coverage.sample(3);
    coverage.sample(1);
    if (coverage.get_inst_coverage() != 100.0)
      $fatal(1, "default array bins changed coverage score");
    $display("PASSED");
  end
endmodule
