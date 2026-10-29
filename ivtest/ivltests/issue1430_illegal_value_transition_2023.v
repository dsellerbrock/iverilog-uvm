module test;
  covergroup cg with function sample(input bit value);
    cp: coverpoint value { bins path = (0 => 1); illegal_bins bad_value = {1}; }
  endgroup

  covergroup control_cg with function sample(input bit value);
    cp: coverpoint value { bins path = (0 => 1); }
  endgroup

  cg cov = new;
  control_cg control = new;

  initial begin
    cov.sample(0);
    cov.sample(1);
    control.sample(0);
    control.sample(1);
    if (cov.get_inst_coverage() != 100.0
        || control.get_inst_coverage() != 100.0)
      $fatal(1, "illegal value suppressed transition coverage: %0.1f / %0.1f",
             cov.get_inst_coverage(), control.get_inst_coverage());
    $display("ISSUE1430_ILLEGAL_VALUE_TRANSITION_PASS");
    $display("PASSED");
  end
endmodule
