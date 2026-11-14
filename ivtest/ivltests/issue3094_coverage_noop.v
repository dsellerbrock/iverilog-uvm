module issue3094_dut;
endmodule

module issue3094_coverage_noop;
  issue3094_dut u();
  integer stop_result, reset_result, check_result, invalid_stop, invalid_reset;
  initial begin
    stop_result = $coverage_control(`SV_COV_STOP, `SV_COV_TOGGLE, `SV_COV_HIER, u);
    reset_result = $coverage_control(`SV_COV_RESET, `SV_COV_TOGGLE, `SV_COV_HIER, u);
    check_result = $coverage_control(`SV_COV_CHECK, `SV_COV_TOGGLE, `SV_COV_HIER, u);
    invalid_stop = $coverage_control(`SV_COV_STOP, `SV_COV_TOGGLE, `SV_COV_HIER, "missing");
    invalid_reset = $coverage_control(`SV_COV_RESET, `SV_COV_TOGGLE, `SV_COV_HIER, "missing");
    if (stop_result !== `SV_COV_OK || reset_result !== `SV_COV_OK ||
        check_result !== `SV_COV_NOCOV || invalid_stop !== `SV_COV_ERROR ||
        invalid_reset !== `SV_COV_ERROR)
      $fatal(1, "stop=%0d reset=%0d check=%0d invalid_stop=%0d invalid_reset=%0d",
             stop_result, reset_result, check_result, invalid_stop, invalid_reset);
    $display("PASS");
  end
endmodule
