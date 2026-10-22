`timescale 1ns/1ps
module d1(input a, output y);
  assign y = a;
  specify (a => y) = 1; endspecify
endmodule

module p32_order;
  reg a = 0;
  wire y;
  d1 u1(a, y);
  initial begin
`ifdef ORDER_AI
    $sdf_annotate("p32_order_ai.sdf", p32_order);
`else
    $sdf_annotate("p32_order_ia.sdf", p32_order);
`endif
    #10 a = 1; #4.5 $display("R1 %b", y); #1 $display("R2 %b", y);
    #4.5 a = 0; #6.5 $display("F1 %b", y); #1 $display("F2 %b", y);
    #1 $finish;
  end
endmodule
