`timescale 1ns/1ps
module dumpports_leaf(input wire value, output wire inverse);
  assign inverse = ~value;
endmodule

module sv_dumpports_multifile;
  reg a_value = 0;
  reg b_value = 1;
  wire a_inverse, b_inverse;
  dumpports_leaf a(a_value, a_inverse);
  dumpports_leaf b(b_value, b_inverse);

  initial begin
    $dumpports(a, "work/sv_dumpports_a.evcd");
    $dumpports(b, "work/sv_dumpports_b.evcd");
    #1 $dumpportsoff("work/sv_dumpports_a.evcd");
    #1 begin a_value = 1; b_value = 0; end
    #1 $dumpportsall("work/unknown.evcd");
    #1 $dumpportson("work/sv_dumpports_a.evcd");
    #1 $dumpportsall;
    #1 begin $dumpportsflush; $display("PASSED"); end
  end
endmodule
