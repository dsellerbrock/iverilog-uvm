module dut(input logic a, output logic y);
  assign y = ~a;
endmodule

module p21_evcd;
  logic a = 0;
  wire y;
  dut u(.a(a), .y(y));

  initial begin
    $dumpports(u, "p21.evcd");
    $dumpportslimit(400, "p21.evcd");
    #1 a = 1;
    #1 a = 0;
    $dumpportsoff("p21.evcd");
    #1 a = 1;
    $dumpportson("p21.evcd");
    #1 a = 0;
    $dumpportsflush("p21.evcd");
    #1 $finish;
  end
endmodule
