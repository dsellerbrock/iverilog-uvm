module issue1421_real_bin_fixed;
  real value;

  covergroup cg;
    type_option.real_interval = 1.0;
    cp: coverpoint value { bins p[2] = {[0.0:2.0]}; }
  endgroup

  cg cov = new;

  initial begin
    value = 0.5;
    cov.sample();
    value = 1.5;
    cov.sample();
    if (cov.cp.get_inst_coverage() != 100.0)
      $fatal(1, "fixed real bins did not cover both intervals");
    $display("PASSED");
  end
endmodule
