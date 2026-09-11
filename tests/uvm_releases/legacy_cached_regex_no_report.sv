// The oldest supported UVM libraries have no SV DPI report callback.
module main;
  import "DPI-C" context uvm_dpi_regcomp = function chandle legacy_compile(string pattern);
  import "DPI-C" context uvm_dpi_regfree = function void legacy_free(chandle expression);
  initial begin
    chandle expression;
    expression=legacy_compile("*[");
    if(expression!=null) $fatal(1,"invalid ERE accepted without report callback");
    legacy_free(expression);
    $display("PASSED"); $finish(0);
  end
endmodule
