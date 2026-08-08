module t;
  initial begin
    // Explicit null arms are actions, not omitted fail arms requesting the
    // default $error report.
    assert #0 (0) else ;
    assert #0 (1) ; else $display("FAILED pass-null routing");
    assert #0 (1) ; else ;
    #1 $display("PASSED");
  end
endmodule
