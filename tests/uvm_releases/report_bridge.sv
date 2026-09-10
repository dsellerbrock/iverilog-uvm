package uvm_pkg;
  int reports=0;
  export "DPI-C" function m__uvm_report_dpi;
  function void m__uvm_report_dpi(int severity, string id, string message,
                                int verbosity, string file, int linenum);
    if (severity != 2 || id != "CHECK" || message != "message" ||
        verbosity != 0 || file != "probe.sv" || linenum != 73)
      $fatal(1,"DPI report arguments corrupted");
    reports++;
  endfunction
endpackage
module main;
  import "DPI-C" context function void m_uvm_report_dpi(
      int severity, string id, string message, int verbosity, string file, int linenum);
  initial begin
    m_uvm_report_dpi(2,"CHECK","message",0,"probe.sv",73);
    if (uvm_pkg::reports != 1) $fatal(1,"DPI report lost: %0d",uvm_pkg::reports);
    $display("PASSED"); $finish(0);
  end
endmodule
