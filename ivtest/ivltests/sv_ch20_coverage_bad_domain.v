// The coverage calls are well typed, but their run-time domain values are
// invalid. IEEE 1800-2017 40.3 requires SV_COV_ERROR, not a silent no-op.
module DUT;
endmodule

module test;
  DUT unit1();
  int errors = 0;
  int invalid = 99;
  logic [31:0] unknown = 'x;

  task automatic expect_error(input string label, input int got);
    if (got !== `SV_COV_ERROR) begin
      errors += 1;
      $display("FAILED %s got=%0d expected=%0d",
               label, got, `SV_COV_ERROR);
    end
  endtask

  initial begin
    expect_error("control",
      $coverage_control(invalid, `SV_COV_TOGGLE, `SV_COV_HIER, unit1));
    expect_error("coverage-type",
      $coverage_get(invalid, `SV_COV_HIER, unit1));
    expect_error("scope",
      $coverage_get(`SV_COV_TOGGLE, invalid, unit1));
    expect_error("unknown-value",
      $coverage_get(unknown, `SV_COV_HIER, unit1));
    expect_error("missing-definition",
      $coverage_get(`SV_COV_TOGGLE, `SV_COV_HIER, "NO_SUCH_MODULE"));
    expect_error("empty-definition",
      $coverage_get(`SV_COV_TOGGLE, `SV_COV_HIER, ""));

    if (errors == 0)
      $display("PASSED");
    else
      $display("FAILED: %0d checks", errors);
  end
endmodule
