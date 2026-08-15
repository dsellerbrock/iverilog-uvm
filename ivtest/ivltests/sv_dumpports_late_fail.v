module dumpports_late_leaf(input wire value);
endmodule
module sv_dumpports_late_fail;
  reg value = 0;
  dumpports_late_leaf a(value);
  dumpports_late_leaf b(value);
  initial begin
    $dumpports(a, "work/sv_dumpports_late_a.evcd");
    #1 $dumpports(b, "work/sv_dumpports_late_b.evcd");
  end
endmodule
