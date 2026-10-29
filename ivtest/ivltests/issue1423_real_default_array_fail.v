module issue1423_real_default_array_fail;
  real value;
  covergroup cg;
    cp: coverpoint value { bins invalid[] = default; }
  endgroup
  cg cov = new;
  initial begin
    value = 0.5;
    cov.sample();
    $display("REAL_DEFAULT_ARRAY_COVERAGE=%0.1f", cov.get_inst_coverage());
    $finish;
  end
endmodule
