// Inspect the KMAC app agent's analysis FIFOs after the token-hash request.
module fifo_probe;
  timeunit 1ps; timeprecision 1ps;
  import uvm_pkg::*;
  import kmac_app_agent_pkg::*;
  initial begin
    uvm_component c;
    kmac_app_monitor mon;
    kmac_app_sequencer sqr;
    #7700000;
    repeat (3) begin
      c = uvm_root::get().find("uvm_test_top.env.m_kmac_app_agent.monitor");
      if (!$cast(mon, c)) $display("FPROBE cast monitor failed (c=%0d)", c != null);
      c = uvm_root::get().find("uvm_test_top.env.m_kmac_app_agent.sequencer");
      if (!$cast(sqr, c)) $display("FPROBE cast sequencer failed (c=%0d)", c != null);
      if (mon != null && sqr != null)
        $display("FPROBE t=%0t data_fifo.used=%0d req_fifo.used=%0d ok_to_end=%0d",
                 $time, mon.data_fifo.used(), sqr.req_analysis_fifo.used(), mon.ok_to_end);
      $fflush;
      #150000;
    end
    $finish;
  end
endmodule
