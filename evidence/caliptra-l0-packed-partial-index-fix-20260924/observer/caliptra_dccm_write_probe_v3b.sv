// Passive bounded observer: raw DCCM bank port activity and core store-buffer commits.
`define B_LSU  caliptra_top_tb.caliptra_top_dut.rvtop.veer.lsu
`define B_DMEM caliptra_top_tb.caliptra_top_dut.rvtop.mem.Gen_dccm_enable.dccm
`define B_RB(b) caliptra_top_tb.tb_services_i.veer_sram_export_inst.Gen_dccm_enable.dccm_loop[b].dccm.dccm_bank
`define B_MX caliptra_top_tb.caliptra_top_dut.rvtop.mem.mem_export
module caliptra_dccm_write_probe_v3b;
  integer n = 0, c = 0;
  always @(posedge caliptra_top_tb.caliptra_top_dut.rvtop.mem.clk) begin
    if (`B_LSU.rst_l === 1'b1 && (`B_DMEM.dccm_wren !== 1'b0 || `B_LSU.lsu_stbuf_commit_any !== 1'b0) && n < 40) begin
      n++;
      $display("V3B_WR t=%0t commit=%b stbuf_addr=%h dmem_wren=%b wr_addr_lo=%h wren_bank=%b addr_bank3=%h clken=%b | tb: ME=%b%b%b%b WE=%b%b%b%b ADR3=%h ADR0=%h D3=%h | mx_wren=%b mx_clken=%b",
        $time, `B_LSU.lsu_stbuf_commit_any, `B_LSU.stbuf_addr_any, `B_DMEM.dccm_wren, `B_DMEM.dccm_wr_addr_lo,
        `B_DMEM.wren_bank, `B_DMEM.addr_bank[3], `B_DMEM.dccm_clken,
        `B_RB(3).ME, `B_RB(2).ME, `B_RB(1).ME, `B_RB(0).ME, `B_RB(3).WE, `B_RB(2).WE, `B_RB(1).WE, `B_RB(0).WE,
        `B_RB(3).ADR, `B_RB(0).ADR, `B_RB(3).D, `B_MX.dccm_wren_bank, `B_MX.dccm_clken);
    end
  end
  always @(posedge `B_RB(3).CLK) if (`B_RB(3).ME === 1'b1 && `B_RB(3).WE === 1'b1 && c < 12) begin
    c++; $display("V3B_BANK3_WRITE t=%0t ADR=%h D=%h", $time, `B_RB(3).ADR, `B_RB(3).D);
  end
endmodule
