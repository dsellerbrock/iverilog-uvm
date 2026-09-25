module tb;
  string path;
  initial begin
    path = "                  tb.dut.u_otp.gen_generic.u_impl_generic.u_prim_ram_1p_adv.u_mem.gen_generic.u_impl_generic.mem";
    $display("PATH=<%s> LEN=%0d FIRST=%0d", path, path.len(), path.getc(0));
    $finish;
  end
endmodule
