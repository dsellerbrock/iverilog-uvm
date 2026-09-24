// Disposable hierarchical monitor only; pinned Caliptra sources are unchanged.
module csrng_addr_hit_monitor;
  csrng_tb tb();
  always @(tb.dut.u_reg.addr_hit) begin
    $display("TRACE_ADDR_HIT t=%0t rst=%b haddr_tb=%h reg_addr=%h reg_re=%b reg_we=%b addrmiss=%b addr_hit=%h",
             $time, tb.reset_n_tb, tb.haddr_i_tb,
             tb.dut.u_reg.reg_addr, tb.dut.u_reg.reg_re, tb.dut.u_reg.reg_we,
             tb.dut.u_reg.addrmiss, tb.dut.u_reg.addr_hit);
  end
endmodule
