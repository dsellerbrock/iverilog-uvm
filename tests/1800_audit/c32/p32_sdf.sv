`timescale 1ns/1ns
module d1(input a, output y); assign y = a; specify (a => y) = 1; endspecify endmodule
module p32_sdf;
  reg a = 0;
  wire y;
  d1 u1(a, y);
  initial begin
    $sdf_annotate("p32.sdf", p32_sdf);
    #10 a = 1; #3 $display("R1 %b", y); #2 $display("R2 %b", y);   // rise 4 -> t14: t13 0, t15 1
    #5 a = 0;  #5 $display("F1 %b", y); #2 $display("F2 %b", y);   // fall 6 -> t26: t25 1, t27 0
  end
endmodule
