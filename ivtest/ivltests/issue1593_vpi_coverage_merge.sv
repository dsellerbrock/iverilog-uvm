module issue1593_vpi_coverage_merge;
  localparam integer SV_COV_ASSERTION = 20;
  localparam integer SV_COV_ERROR = -1;

  initial begin
    $issue1593_coverage_merge;
    if ($coverage_merge(SV_COV_ASSERTION, "missing") !== SV_COV_ERROR) begin
      $display("system coverage merge did not report SV_COV_ERROR");
      $fatal(1);
    end
    $display("PASSED");
    $finish;
  end
endmodule
