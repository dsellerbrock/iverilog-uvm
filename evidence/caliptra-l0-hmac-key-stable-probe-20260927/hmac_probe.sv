// Diagnostic-only observer for smoke_test_hmac ERR_HMAC_KEY_NOT_STABLE.
// Compiled as a second top next to the unmodified sources; drives nothing.
`timescale 1ns/1ps
module hmac_probe;
  `define H caliptra_top_tb.caliptra_top_dut.hmac.hmac_inst
  always @(posedge `H.clk) begin
    if ($realtime >= 745000.0 && $realtime <= 761000.0) begin
      $display("PRE  t=%0t rst_n=%b core_ready=%b ready_reg=%b csr_mode=%b init=%b next=%b key0=%h key15=%h",
               $realtime, `H.reset_n, `H.core_ready, `H.ready_reg,
               `H.hwif_out.HMAC512_CTRL.CSR_MODE.value, `H.init_reg, `H.next_reg,
               `H.key_reg[0], `H.key_reg[15]);
      $strobe("POST t=%0t rst_n=%b core_ready=%b ready_reg=%b csr_mode=%b init=%b next=%b key0=%h key15=%h",
               $realtime, `H.reset_n, `H.core_ready, `H.ready_reg,
               `H.hwif_out.HMAC512_CTRL.CSR_MODE.value, `H.init_reg, `H.next_reg,
               `H.key_reg[0], `H.key_reg[15]);
    end
  end
endmodule
