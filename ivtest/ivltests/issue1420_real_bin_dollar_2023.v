module issue1420_real_bin_dollar_2023;
`ifdef ISSUE1420_2023
  real value;
  covergroup cg;
    type_option.real_interval = 1.0;
    cp: coverpoint value { bins p[] = {[$:0.75]}; }
`else
  int value;
  covergroup cg;
    cp: coverpoint value { bins p = {[$:75]}; }
`endif
  endgroup
  cg cov = new;
  initial begin
`ifdef ISSUE1420_2023
    value = 0.5;
`else
    value = 50;
`endif
    cov.sample();
    if (cov.cp.get_inst_coverage() != 100.0)
      $fatal(1, "dollar-bounded real bin was not sampled");
    $display("PASSED");
  end
endmodule
