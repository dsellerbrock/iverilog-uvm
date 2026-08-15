module dumpports_limit_leaf(input wire value);
endmodule

module sv_dumpports_limit_prestart;
  reg value = 0;
  dumpports_limit_leaf dut(value);
  initial begin
    $dumpports(dut, "work/sv_dumpports_limit.evcd");
    $dumpportslimit(1, "work/sv_dumpports_limit.evcd");
    #1 $display("PASSED");
  end
endmodule
