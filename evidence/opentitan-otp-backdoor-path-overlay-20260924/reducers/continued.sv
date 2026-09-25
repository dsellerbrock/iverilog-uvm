`define DV_STRINGIFY(I_) `"I_`"
`define MEM_MODULE_PATH \
        tb.dut.u_otp.gen_generic.u_impl_generic.u_prim_ram_1p_adv
`define MEM_ARRAY_PATH \
        `MEM_MODULE_PATH.u_mem.gen_generic.u_impl_generic.mem
module tb;
  string path;
  initial begin
    path = `DV_STRINGIFY(`MEM_ARRAY_PATH);
    $display("PATH=<%s> LEN=%0d FIRST=%0d", path, path.len(), path.getc(0));
    $finish;
  end
endmodule
