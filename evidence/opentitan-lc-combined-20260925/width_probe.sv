module width_probe;
  timeunit 1ps; timeprecision 1ps;
  initial begin
    #7690300;
    $display("WPROBE bits: kmac_data_req=%0d req_if.h_data=%0d KMAC_REQ_DATA_WIDTH=%0d",
      $bits(tb.kmac_app_if.kmac_data_req), $bits(tb.kmac_app_if.req_data_if.h_data),
      kmac_app_agent_pkg::KMAC_REQ_DATA_WIDTH);
    $display("WPROBE t=%0t kmac_data_req=%h req_if.valid=%b req_if.h_data=%h dut.kmac_data_o=%h",
      $time, tb.kmac_app_if.kmac_data_req, tb.kmac_app_if.req_data_if.valid,
      tb.kmac_app_if.req_data_if.h_data, tb.kmac_data_out);
    $fflush; $finish;
  end
endmodule
