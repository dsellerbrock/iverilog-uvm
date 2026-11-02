module issue1422_real_auto_bins_fail;
  real value;
  covergroup cg;
    cp: coverpoint value;
  endgroup
  cg cov = new;
  initial begin
    value = 0.5;
    cov.sample();
    $display("REAL_AUTO_COVERAGE=%0.1f", cov.get_inst_coverage());
    $finish;
  end
endmodule
