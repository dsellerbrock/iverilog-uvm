`timescale 1ns/1ns
module d1(input a, output y);
  assign y = a;
  specify (a => y) = 1; endspecify
endmodule

module p32_mtm;
  reg a = 0;
  wire y;
  d1 u1(a, y);
  always @(y) if ($time > 0) $display("Y %0t %b", $time, y);
  initial begin
`ifdef MTM_MINIMUM
    $sdf_annotate("p32_mtm.sdf", p32_mtm, "", "", "MINIMUM");
`elsif MTM_TYPICAL
    $sdf_annotate("p32_mtm.sdf", p32_mtm, "", "", "TYPICAL");
`elsif MTM_MAXIMUM
    $sdf_annotate("p32_mtm.sdf", p32_mtm, "", "", "MAXIMUM");
`endif
    #10 a = 1;
    #20 a = 0;
    #30 $finish;
  end
endmodule
