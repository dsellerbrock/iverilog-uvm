module fifo_probe4;
  timeunit 1ps; timeprecision 1ps;
  import uvm_pkg::*;
  import kmac_app_agent_pkg::*;
  initial begin
    uvm_component c;
    kmac_app_monitor mon;
    kmac_app_sequencer sqr;
    #8010000;
    c = uvm_root::get().find("uvm_test_top.env.m_kmac_app_agent.monitor"); void'($cast(mon, c));
    c = uvm_root::get().find("uvm_test_top.env.m_kmac_app_agent.sequencer"); void'($cast(sqr, c));
    repeat (6) begin
      $display("F4 t=%0t mon.used=%0d ok_to_end=%0d sqr.req_fifo.used=%0d has_share=%0d",
        $time, mon.data_fifo.used(), mon.ok_to_end, sqr.req_analysis_fifo.used(), mon.cfg.has_user_digest_share());
      #20000;
    end
    $fflush; $finish;
  end
endmodule
