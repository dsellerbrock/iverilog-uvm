module main;
  import uvm_pkg::*;
  import "DPI-C" context uvm_dpi_regcomp = function chandle legacy_compile(string pattern);
  import "DPI-C" context uvm_dpi_regexec = function int legacy_execute(chandle expression, string text);
  import "DPI-C" context uvm_dpi_regfree = function void legacy_free(chandle expression);
  initial begin
    uvm_root root;
    uvm_report_server server;
    chandle first, second, invalid;
    int errors_before;
    root=uvm_root::get(); server=uvm_report_server::get_server();
    root.set_report_severity_action(UVM_ERROR,UVM_COUNT);
    errors_before=server.get_severity_count(UVM_ERROR);
    first=legacy_compile("^item[0-9]+$");
    second=legacy_compile("^other$");
    if(first==null || second==null) $fatal(1,"legacy regex compilation");
    if(legacy_execute(first,"item42")!=0 || legacy_execute(first,"itemX")==0 ||
       legacy_execute(first,"prefix_item42")==0 || legacy_execute(second,"other")!=0)
      $fatal(1,"cached regex match polarity or anchors");
    legacy_free(first);
    if(legacy_execute(second,"other")!=0 || legacy_execute(second,"item42")==0)
      $fatal(1,"independent handle lifetime");
    legacy_free(second);
    // Repeated compile/free must not leave the next handle unusable.
    repeat(32) begin
      first=legacy_compile("^$");
      if(first==null || legacy_execute(first,"")!=0 || legacy_execute(first,"x")==0)
        $fatal(1,"empty match or handle reuse");
      legacy_free(first);
    end
    if(legacy_execute(null,"anything")==0) $fatal(1,"null handle matched");
    legacy_free(null);
    // Invalid even on hosts accepting a leading-star ERE extension.
    invalid=legacy_compile("*[");
    if(invalid!=null) $fatal(1,"invalid ERE accepted or retried as glob");
    legacy_free(invalid);
`ifdef LEGACY_PRINT_REPORT
    // Original 1.1d has no SV DPI report callback; the harness checks
    // the native diagnostic, and no UVM severity count may be fabricated.
    if(server.get_severity_count(UVM_ERROR)!=errors_before)
      $fatal(1,"unexpected UVM severity count");
`else
    if(server.get_severity_count(UVM_ERROR)!=errors_before+1 ||
       server.get_id_count("UVM/DPI/REGCOMP")!=1)
      $fatal(1,"invalid regex did not report exactly one UVM error");
`endif
    $display("PASSED"); $finish(0);
  end
endmodule
