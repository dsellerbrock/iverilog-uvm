// DPI export multi-instance (IEEE 1800-2017 35.5.2 / H.9 svScope): a module
// exporting a function is instantiated twice; C selects which instance to
// run with svSetScope(svGetScopeFromName("...")). The exported subroutine
// reads a per-instance parameter, so a correct selection is observable in
// the returned value. Also exercises a $display from within the exported
// SV body (which requires the runtime to run it in VPI_MODE_NONE).
module m10d_sub #(parameter int K = 0) ();
  function int addk(int a);
    $display("  m10d_sub.addk: K=%0d a=%0d", K, a);
    return a + K;
  endfunction
  export "DPI-C" function addk;
endmodule

module m10d_dpi_export_multiinst_test;
  import "DPI-C" context function int c_run();
  m10d_sub #(.K(100)) u1();
  m10d_sub #(.K(200)) u2();
  initial begin
    if (c_run() == 0) $display("PASS m10d_dpi_export_multiinst_test");
    else               $display("FAIL m10d_dpi_export_multiinst_test");
    $finish;
  end
endmodule
