`timescale 1ns/1ns
module d1(input a, output y); assign y = a; specify (a => y) = 1; endspecify endmodule
module p32_pp;
  reg a = 0;
  wire y;
  d1 u1(a, y);
  always @(y) $display("Y %0t %b", $time, y);
  initial begin
    $sdf_annotate("p32_pp.sdf", p32_pp);
    #10 a = 1; #1 a = 0;     // width 1 < reject 2: filtered, no output pulse
    #20 a = 1; #2 a = 0;     // reject <= width < error: output pulse becomes x
    #20 a = 1; #5 a = 0;     // width >= error 3: output pulse propagates
    #20 $finish;
  end
endmodule
