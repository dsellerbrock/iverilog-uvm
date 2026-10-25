`timescale 1ns/1ps
module d1(input a, output y);
  assign y = a;
  specify (a => y) = 1; endspecify
endmodule

module p32_multi;
  reg a = 0;
  wire y1, y2;
  d1 u1(a, y1);
  d1 u2(a, y2);
  initial begin
    $sdf_annotate("p32_multi_a.sdf", p32_multi.u1);
    $sdf_annotate("p32_multi_b.sdf", p32_multi.u2);
    $sdf_annotate("p32_multi_c.sdf", p32_multi.u1);
    #10 a = 1;
    #4.5 $display("R1 %b%b", y1, y2);
    #2 $display("R2 %b%b", y1, y2);
    #1 $display("R3 %b%b", y1, y2);
    #12.5 a = 0;
    #6.5 $display("F1 %b%b", y1, y2);
    #2 $display("F2 %b%b", y1, y2);
    #1 $display("F3 %b%b", y1, y2);
    #1 $finish;
  end
endmodule
