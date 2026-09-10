module main;
  import uvm_pkg::*;
  import "DPI-C" context function void m_uvm_report_dpi(
      int severity, string id, string message, int verbosity, string file, int linenum);
  initial begin
    uvm_root root;
    uvm_report_server server;
    int errors_before, warnings_before;
    root=uvm_root::get();
    server=uvm_report_server::get_server();
    root.set_report_severity_action(UVM_ERROR,UVM_COUNT);
    root.set_report_severity_action(UVM_WARNING,UVM_COUNT);
    errors_before=server.get_severity_count(UVM_ERROR);
    warnings_before=server.get_severity_count(UVM_WARNING);
    m_uvm_report_dpi(UVM_ERROR,"BRIDGE_ERROR","expected error",UVM_NONE,"probe.sv",73);
    m_uvm_report_dpi(UVM_WARNING,"BRIDGE_WARNING","expected warning",UVM_NONE,"probe.sv",91);
    if (server.get_severity_count(UVM_ERROR) != errors_before+1 ||
        server.get_severity_count(UVM_WARNING) != warnings_before+1 ||
        server.get_id_count("BRIDGE_ERROR") != 1 ||
        server.get_id_count("BRIDGE_WARNING") != 1)
      $fatal(1,"DPI reports did not reach the UVM report server");
    $display("PASSED"); $finish(0);
  end
endmodule
