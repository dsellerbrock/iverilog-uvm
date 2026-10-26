// IEEE 1800-2017/2023 19.5.3: the final automatic bin gets the remainder.
module top;
  bit [2:0] value;
  covergroup cg;
    option.auto_bin_max = 3;
    cp: coverpoint value;
  endgroup
  cg cov = new;
  initial begin
    value = 0; cov.sample();
    value = 2; cov.sample();
    value = 4; cov.sample();
    if (cov.get_inst_coverage() != 100.0)
      $fatal(1, "expected 100%% coverage after sampling 0, 2, 4; got %0.1f",
             cov.get_inst_coverage());
    $display("PASSED");
  end
endmodule
