module sram_ctrl_mubi_coverpoint_width_repro;
`ifdef NARROW
  covergroup executable_cg with function sample(logic [2:0] csr_exec);
`else
  covergroup executable_cg with function sample(logic [3:0] csr_exec);
`endif
    csr_exec_cp: coverpoint csr_exec {
      bins instr_en = {4'h6};
      bins instr_valid_dis = {4'h9};
    }
  endgroup
  executable_cg cg;
  initial begin
    cg = new;
    cg.sample(4'h9);
`ifdef NARROW
    if (cg.get_coverage() != 0) $fatal(1, "expected false bin to be lost");
`else
    if (cg.get_coverage() != 50) $fatal(1, "4-bit false bin not sampled");
`endif
    cg.sample(4'h6);
    if (cg.get_coverage() != 100) $fatal(1, "coverage incomplete");
    $display("PASS coverage %0f", cg.get_coverage());
  end
endmodule
