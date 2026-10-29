module issue1423_real_default_scalar;
  real value;
  covergroup cg;
    cp: coverpoint value { bins all_values = default; }
  endgroup
  cg cov = new;
  initial begin
    value = 0.5;
    cov.sample();
    $display("REAL_DEFAULT_SCALAR_COVERAGE=%0.1f",
             cov.get_inst_coverage());
    $display("PASSED");
  end
endmodule
