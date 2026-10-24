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

primitive dominance(q, clk, clr);
  output q;
  reg q;
  input clk, clr;
  initial q = 0;
  table
  // clk  clr : q : q+
     ?    1   : ? : 0;
     f    ?   : 0 : 1;
  endtable
endprimitive

module p29_more;
  reg clk = 0, d = 1, clr = 0;
  reg dom_clk = 1, dom_clr = 1;
  wire q1, qanon, dom_q;
  wire [1:0] qv;

  latchff #(2, 3) u1(q1, clk, d, clr);
  latchff (qanon, clk, d, clr);
  latchff ua[1:0](qv, clk, d, clr);
  dominance ud(dom_q, dom_clk, dom_clr);

  initial begin
    #5 clk = 1; dom_clk = 0;
    #1 $display("I1 %b %b", q1, qanon);
    #2 $display("I2 %b %b", q1, qv);
    #2 clr = 1; clk = 0;
    #10 clk = 1; #5 $display("D1 %b %b", q1, qv);
    $display("DOM %b", dom_q);
  end
endmodule
