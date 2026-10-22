`timescale 1ns/1ns
module d1(input a, output y);
  assign y = a;
  specify (a => y) = 1; endspecify
endmodule

module p32_scale;
  reg a = 0;
  wire y;
  d1 u1(a, y);
  always @(y) if ($time > 0) $display("Y %0t %b", $time, y);
  initial begin
    $sdf_annotate("p32_scale.sdf", p32_scale, "", "", "TYPICAL", "2.0:2.0:2.0", "FROM_TYPICAL");
    #10 a = 1;
    #20 a = 0;
    #30 $finish;
  end
endmodule
