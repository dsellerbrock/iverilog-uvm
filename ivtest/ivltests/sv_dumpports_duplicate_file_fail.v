module dumpports_file_leaf(input wire value);
endmodule
module sv_dumpports_duplicate_file_fail;
  reg value = 0;
  dumpports_file_leaf a(value);
  dumpports_file_leaf b(value);
  initial begin
    $dumpports(a, "work/sv_dumpports_duplicate_file.evcd");
    $dumpports(b, "work/sv_dumpports_duplicate_file.evcd");
  end
endmodule
