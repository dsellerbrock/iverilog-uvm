module fifo_probe3;
  timeunit 1ps; timeprecision 1ps;
  import uvm_pkg::*;
  import kmac_app_agent_pkg::*;
  kmac_app_monitor mon;
  initial begin
    uvm_component c;
    #7600000;
    c = uvm_root::get().find("uvm_test_top.env.m_kmac_app_agent.monitor");
    void'($cast(mon, c));
    repeat (80) begin
      #5000;
      if (mon.data_fifo.used() != 0 || ($time > 7685000 && $time < 7700000) || ($time > 7975000 && $time < 7990000))
        $display("F3 t=%0t used=%0d ok_to_end=%0d push_valid=%b push_ready=%b", $time, mon.data_fifo.used(), mon.ok_to_end,
                 tb.kmac_app_if.req_data_if.valid, tb.kmac_app_if.req_data_if.ready);
    end
    $fflush; $finish;
  end
  always @(tb.kmac_app_if.req_data_if.mon_cb)
    if ($time > 7600000 && $time < 8000000 && tb.kmac_app_if.req_data_if.mon_cb.valid && tb.kmac_app_if.req_data_if.mon_cb.ready)
      $display("F3 mon_cb handshake t=%0t h_data=%h", $time, tb.kmac_app_if.req_data_if.mon_cb.h_data);
endmodule
