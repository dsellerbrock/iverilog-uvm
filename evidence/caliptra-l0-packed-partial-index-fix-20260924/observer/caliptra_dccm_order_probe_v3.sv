// Passive diagnostic observer (outside the selected-52 numerator).
// Separate root module: references pinned hierarchy read-only; no force/deposit.
`define V3_LSU  caliptra_top_tb.caliptra_top_dut.rvtop.veer.lsu
`define V3_DMEM caliptra_top_tb.caliptra_top_dut.rvtop.mem.Gen_dccm_enable.dccm
`define V3_RB(b) caliptra_top_tb.tb_services_i.veer_sram_export_inst.Gen_dccm_enable.dccm_loop[b].dccm.dccm_bank
module caliptra_dccm_order_probe_v3;
  integer seq = 0;
  integer win = 0;          // remaining clk edges in the first-DCCM-read window
  integer armed = 0;        // first DCCM read seen
  integer wr_x = 0, mx_edges = 0;

  // (a) preload integrity: X entries per bank right after preload
  task automatic scan(input integer b);
    integer i, n, first; n = 0; first = -1;
    for (i = 0; i < 16384; i++) begin
      logic [38:0] v;
      case (b) 0: v = `V3_RB(0).ram_core[i]; 1: v = `V3_RB(1).ram_core[i];
               2: v = `V3_RB(2).ram_core[i]; default: v = `V3_RB(3).ram_core[i]; endcase
      if ($isunknown(v)) begin n++; if (first < 0) first = i; end
    end
    $display("V3_PRELOAD_SCAN t=%0t bank=%0d x_entries=%0d first_x=%0d", $time, b, n, first);
  endtask
  initial begin
    wait (caliptra_top_tb.tb_services_i.preload_dccm_done === 1'b1);
    #1; scan(0); scan(1); scan(2); scan(3);
  end

  // (b) every RAM write: log X write data, and the .data word at 0x5002007c (bank 3, index 0x2007)
`define V3_WR(b) \
  always @(posedge `V3_RB(b).CLK) if (`V3_RB(b).ME === 1'b1 && `V3_RB(b).WE === 1'b1) begin \
    if ($isunknown(`V3_RB(b).D) && wr_x < 16) begin wr_x++; \
      $display("V3_WRITE_X t=%0t bank=%0d adr=%h d=%h", $time, b, `V3_RB(b).ADR, `V3_RB(b).D); end \
    if (b == 3 && `V3_RB(b).ADR === 14'h2007) begin \
      $display("V3_TARGET_WRITE t=%0t bank=3 adr=%h d=%h", $time, `V3_RB(b).ADR, `V3_RB(b).D); \
      @(posedge `V3_RB(b).CLK) $display("V3_TARGET_STORED t=%0t ram_core=%h", $time, `V3_RB(3).ram_core[14'h2007]); end \
    if (win > 0) $display("V3_EV seq=%0d t=%0t RAMWRITE bank=%0d adr=%h d=%h", seq++, $time, b, `V3_RB(b).ADR, `V3_RB(b).D); \
  end
  `V3_WR(0) `V3_WR(1) `V3_WR(2) `V3_WR(3)

  // (c) window after the first DCCM read port request: intra-timestep event order
  always @(posedge `V3_RB(0).CLK) begin
    if (!armed && `V3_DMEM.dccm_rden === 1'b1 && `V3_LSU.rst_l === 1'b1) begin
      armed = 1; win = 12;
      $display("V3_FIRST_DCCM_READ t=%0t rd_addr_lo=%h rd_addr_hi=%h", $time, `V3_DMEM.dccm_rd_addr_lo, `V3_DMEM.dccm_rd_addr_hi);
    end
    if (win > 0) begin
      $display("V3_EV seq=%0d t=%0t RAMCLK_POSEDGE rden=%b wren=%b rden_bank=%b wren_bank=%b rd_lo=%h wr_lo=%h rd_addr_lo_q=%h Q3=%h Q0=%h m=%b r=%b stbuf_vld=%b stbuf_commit=%b stbuf_addr=%h lsu_addr_d=%h",
        seq++, $time, `V3_DMEM.dccm_rden, `V3_DMEM.dccm_wren, `V3_DMEM.rden_bank, `V3_DMEM.wren_bank,
        `V3_DMEM.dccm_rd_addr_lo, `V3_DMEM.dccm_wr_addr_lo, `V3_DMEM.dccm_rd_addr_lo_q,
        `V3_RB(3).Q, `V3_RB(0).Q, `V3_LSU.lsu_double_ecc_error_m, `V3_LSU.lsu_double_ecc_error_r,
        `V3_LSU.stbuf_reqvld_any, `V3_LSU.lsu_stbuf_commit_any, `V3_LSU.stbuf_addr_any, `V3_LSU.lsu_addr_d);
      $strobe("V3_EV_POSTNBA t=%0t m=%b r=%b Q3=%h Q0=%h rd_data_lo=%h lo_en=%b", $time,
        `V3_LSU.lsu_double_ecc_error_m, `V3_LSU.lsu_double_ecc_error_r, `V3_RB(3).Q, `V3_RB(0).Q,
        `V3_DMEM.dccm_rd_data_lo, `V3_LSU.ecc.is_ldst_lo_any);
      win = win - 1;
    end
  end
  always @(posedge `V3_LSU.lsu_c2_r_clk) begin
    if (win > 0)
      $display("V3_EV seq=%0d t=%0t C2R_POSEDGE m_seen_by_r=%b r=%b lo_en=%b rd_data_lo=%h Q3=%h", seq++, $time,
        `V3_LSU.lsu_double_ecc_error_m, `V3_LSU.lsu_double_ecc_error_r, `V3_LSU.ecc.is_ldst_lo_any,
        `V3_DMEM.dccm_rd_data_lo, `V3_RB(3).Q);
    if (armed && $isunknown(`V3_LSU.lsu_double_ecc_error_m) && mx_edges < 8) begin
      mx_edges++;
      $display("V3_C2R_SAMPLES_X t=%0t m=%b lo_en=%b hi_en=%b rd_data_lo=%h rd_addr_lo_q=%h Q0=%h Q1=%h Q2=%h Q3=%h", $time,
        `V3_LSU.lsu_double_ecc_error_m, `V3_LSU.ecc.is_ldst_lo_any, `V3_LSU.ecc.is_ldst_hi_any,
        `V3_DMEM.dccm_rd_data_lo, `V3_DMEM.dccm_rd_addr_lo_q, `V3_RB(0).Q, `V3_RB(1).Q, `V3_RB(2).Q, `V3_RB(3).Q);
    end
  end
  always @(`V3_RB(3).Q) if (win > 0) $display("V3_EV seq=%0d t=%0t Q3_CHANGE Q3=%h", seq++, $time, `V3_RB(3).Q);
  always @(`V3_RB(0).Q) if (win > 0) $display("V3_EV seq=%0d t=%0t Q0_CHANGE Q0=%h", seq++, $time, `V3_RB(0).Q);
  always @(`V3_LSU.lsu_double_ecc_error_m) if (win > 0) $display("V3_EV seq=%0d t=%0t M_CHANGE m=%b", seq++, $time, `V3_LSU.lsu_double_ecc_error_m);
  always @(`V3_LSU.lsu_double_ecc_error_r) if (armed) $display("V3_EV seq=%0d t=%0t R_CHANGE r=%b", seq++, $time, `V3_LSU.lsu_double_ecc_error_r);
endmodule
