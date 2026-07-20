// DPI export context-relative default (IEEE 1800-2017 35.5.2): a `context'
// imported function that calls an exported subroutine WITHOUT svSetScope
// runs it in the import's own instance (the "current context"). The
// exported function reads a per-instance parameter, so the correct default
// selection is observable: called from instance u1 it must run u1's copy.
module m10e_sub #(parameter int K = 0) ();
  import "DPI-C" context function int m10e_ctx();
  function int m10e_localf(int a);
    return a + K;
  endfunction
  export "DPI-C" function m10e_localf;

  int r;
  initial begin
    #1 r = m10e_ctx();  // C calls m10e_localf(1) with no svSetScope
    if (r == 1 + K)
      $display("  m10e_sub(K=%0d): context default correct (r=%0d) PASS", K, r);
    else
      $display("  m10e_sub(K=%0d): FAIL got %0d expected %0d", K, r, 1 + K);
  end
endmodule

module m10e_dpi_export_context_test;
  m10e_sub #(.K(10)) u1();
  m10e_sub #(.K(20)) u2();
  initial begin
    #5 $display("PASS m10e_dpi_export_context_test");
    $finish;
  end
endmodule
