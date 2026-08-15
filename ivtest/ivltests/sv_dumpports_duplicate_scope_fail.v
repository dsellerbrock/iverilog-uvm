module dumpports_duplicate_leaf(input wire value);
endmodule
module sv_dumpports_duplicate_scope_fail;
  reg value = 0;
  dumpports_duplicate_leaf dut(value);
  initial begin
    $dumpports(dut, "work/sv_dumpports_duplicate_a.evcd");
    $dumpports(dut, "work/sv_dumpports_duplicate_b.evcd");
  end
endmodule
