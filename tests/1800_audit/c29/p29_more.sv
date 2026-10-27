`timescale 1ns/1ps

primitive latchff(q, clk, d, clr);
  output q;
  reg q;
  input clk, d, clr;
  table
  // clk  d  clr : q : q+
     ?    ?   1  : ? : 0;
     r    0   0  : ? : 0;
     r    1   0  : ? : 1;
     f    ?   0  : ? : -;
     ?    *   0  : ? : -;
  endtable
endprimitive

module p29_more;
  reg clk = 0, d = 1, clr = 0;
  wire q1, qanon;

  latchff #(2, 3) u1(q1, clk, d, clr);
  latchff (qanon, clk, d, clr);

  initial begin
    #5 clk = 1;
    #1 $display("I1 %b %b", q1, qanon);
    #2 $display("I2 %b %b", q1, qanon);
    #2 clr = 1; clk = 0;
    #10 clk = 1; #5 $display("D1 %b %b", q1, qanon);
  end
endmodule
