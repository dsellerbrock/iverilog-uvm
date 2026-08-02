// IEEE 1800-2017 19.8.1/13.5.3: default-valued formals on a covergroup's
// with-function sample method may be omitted at a call site. OpenTitan uses
// three positional actuals for a four-formal sample method whose last formal
// defaults to zero.
module covergroup_sample_default_formal_test;
  covergroup value_cg with function sample(bit value, bit enable = 1);
    cp: coverpoint value iff (enable);
  endgroup

  value_cg cov;
  initial begin
    cov = new();
    cov.sample(0);
    cov.sample(1, 0);
    if ($rtoi(cov.get_inst_coverage()) != 50)
      $fatal(1, "default sample formal was not applied: %0f",
             cov.get_inst_coverage());
    $display("COVERGROUP SAMPLE DEFAULT FORMAL TEST: PASS");
    $finish(0);
  end
endmodule
