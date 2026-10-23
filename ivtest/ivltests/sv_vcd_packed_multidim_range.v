module sv_vcd_packed_multidim_range;
  logic [1:0][3:0] data;

  initial begin
    $dumpfile("sv_vcd_packed_multidim_range.vcd");
    $dumpvars(0, sv_vcd_packed_multidim_range);
    data = 8'ha5;
    #1;
    $dumpflush;
    if ($system("grep -Fq 'reg 8 ! data [7:0]' sv_vcd_packed_multidim_range.vcd") != 0)
      $fatal(1, "multidimensional packed VCD range was not collapsed");
    $display("collapsed VCD range PASS");
    $finish;
  end
endmodule
