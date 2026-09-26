module fifo_probe2;
  timeunit 1ps; timeprecision 1ps;
  import uvm_pkg::*;
  import kmac_app_agent_pkg::*;
  import push_pull_agent_pkg::*;
  int negs, poss;
  always @(negedge tb.kmac_app_if.rst_n) negs++;
  always @(posedge tb.kmac_app_if.rst_n) poss++;
  initial begin
    uvm_component c;
    kmac_app_monitor mon;
    push_pull_monitor#(`CONNECT_DATA_WIDTH) pmon;
    #8000000;
    c = uvm_root::get().find("uvm_test_top.env.m_kmac_app_agent.monitor");
    void'($cast(mon, c));
    c = uvm_root::get().find("uvm_test_top.env.m_kmac_app_agent.m_data_push_agent.monitor");
    if (!$cast(pmon, c)) $display("FPROBE2 push monitor cast failed");
    $display("FPROBE2 t=%0t mon=%0d pmon=%0d ap.size=%0d fifo.used=%0d vif.rst_n=%b if.rst_n negs=%0d poss=%0d",
      $time, mon != null, pmon != null, pmon != null ? pmon.analysis_port.size() : -1,
      mon != null ? mon.data_fifo.used() : -1, mon != null ? mon.cfg.vif.rst_n : 1'bz, negs, poss);
    $fflush; $finish;
  end
endmodule
