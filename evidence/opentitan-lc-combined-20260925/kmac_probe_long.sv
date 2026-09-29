// Trace the KMAC app request/response around the lc_ctrl token hash.
module kmac_probe_long;
  timeunit 1ps; timeprecision 1ps;
  bit armed; int n;
  initial begin #6850000; armed = 1; #23000000; $display("KPROBE END t=%0t fsm=%0d", $time, tb.dut.u_lc_ctrl_fsm.fsm_state_q); $fflush; $finish; end
  always @(tb.kmac_data_out or tb.kmac_data_in or tb.kmac_app_if.rsp_done or tb.kmac_app_if.req_data_if.ready or tb.kmac_app_if.req_data_if.valid)
    if (armed && n < 400) begin
      n++;
      $display("KPROBE t=%0t req.valid=%b req.last=%b | if.valid=%b if.ready=%b | rsp.ready=%b rsp.done=%b rsp.error=%b | if.rsp_done=%b mode=%0d",
        $time, tb.kmac_data_out.valid, tb.kmac_data_out.last,
        tb.kmac_app_if.req_data_if.valid, tb.kmac_app_if.req_data_if.ready,
        tb.kmac_data_in.ready, tb.kmac_data_in.done, tb.kmac_data_in.error,
        tb.kmac_app_if.rsp_done, tb.kmac_app_if.if_mode);
      $fflush;
    end
endmodule
module fsm_probe_long;
  timeunit 1ps; timeprecision 1ps;
  always @(tb.dut.u_lc_ctrl_fsm.fsm_state_q) if ($time > 6600000) begin $display("FSMP t=%0t state=%0d", $time, tb.dut.u_lc_ctrl_fsm.fsm_state_q); $fflush; end
endmodule
